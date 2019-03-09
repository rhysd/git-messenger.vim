let s:blame = {}

function! s:git_cmd_failure(git) abort
    return printf(
        \   '`%s %s` exited with non-zero status %d: %s',
        \   a:git.cmd,
        \   join(a:git.args, ' '),
        \   a:git.exit_status,
        \   join(a:git.stderr, ' ')
        \ )
endfunction

function! s:blame__back() dict abort
    let next_index = self.index + 1

    if len(self.history) > next_index
        let self.index = next_index
        let self.contents = self.history[next_index]
        let self.popup.contents = self.contents
        call self.popup.update()
        return
    endif

    if self.oldest_commit =~# '^0\+$'
        echom 'git-messenger: No older commit found'
        return
    endif

    let args = ['--no-pager', 'blame', self.oldest_commit, self.file, '-L', self.line . ',+1', '--porcelain']
    let cwd = fnamemodify(self.file, ':p:h')
    let git = gitmessenger#git#new(g:git_messenger_git_command)
    call git.spawn(args, cwd, funcref('s:blame__after_blame', [], self))
endfunction
let s:blame.back = funcref('s:blame__back')

function! s:blame__forward() dict abort
    let next_index = self.index - 1
    if next_index < 0
        echom 'git-messenger: The latest commit'
        return
    endif

    let self.index = next_index
    let self.contents = self.history[next_index]
    let self.popup.contents = self.contents
    call self.popup.update()
endfunction
let s:blame.forward = funcref('s:blame__forward')

function! s:blame__open_popup() dict abort
    if has_key(self, 'popup') && has_key(self.popup, 'bufnr')
        let self.history += [self.contents]
        let self.index = len(self.history) - 1
        let self.popup.contents = self.contents
        call self.popup.update()
        return
    endif

    let opts = {
        \   'filetype': 'gitmessengerpopup',
        \   'mappings': {
        \       'q': {-> execute('close')},
        \       'h': funcref(self.back, [], self),
        \       'l': funcref(self.forward, [], self),
        \   },
        \ }
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif

    let self.history = [self.contents]
    let self.popup = gitmessenger#popup#new(self.contents, opts)
    call self.popup.open()

    if has_key(self.opts, 'did_open')
        call self.opts.did_open(self)
    endif
endfunction
let s:blame.open_popup = funcref('s:blame__open_popup')

function! s:blame__after_log(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        throw s:git_cmd_failure(a:git)
    endif

    if a:git.stdout != ['']
        for line in a:git.stdout
            if line ==# ''
                let self.contents += ['']
            else
                let self.contents += [' ' . line]
            endif
        endfor
        if self.contents[-1] !=# ''
            let self.contents += ['']
        endif
    endif

    call self.open_popup()
endfunction

function! s:blame__after_blame(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        if a:git.stderr[0] =~# 'has only \d\+ lines'
            echom 'git-messenger: ' . get(self, 'oldest_commit', 'It') . ' is the oldest commit2'
            return
        endif
        throw s:git_cmd_failure(a:git)
    endif

    " Parse `blame --porcelain` output
    let stdout = a:git.stdout
    let hash = matchstr(stdout[0], '^\S\+')
    if has_key(self, 'oldest_commit') && self.oldest_commit ==# hash
        echom 'git-messenger: ' . hash . ' is the oldest commit'
        return
    endif

    let author = matchstr(stdout[1], '^author \zs.\+')
    let author_email = matchstr(stdout[2], '^author-mail \zs\S\+')
    let self.contents = [
        \   '',
        \   ' History: #' . len(self.history),
        \   ' Commit: ' . hash,
        \   ' Author: ' . author . ' ' . author_email,
        \ ]
    let committer = matchstr(stdout[5], '^committer \zs.\+')
    if author !=# committer
        let committer_email = matchstr(stdout[6], '^committer-mail \zs\S\+')
        let self.contents += [' Committer: ' . committer . ' ' . committer_email]
    endif
    let summary = matchstr(stdout[9], '^summary \zs.*')
    let self.contents += ['', ' ' . summary, '']

    let self.oldest_commit = hash

    " Check hash is 0000000000000000000000 it means that the line is not commited yet
    if hash =~# '^0\+$'
        call self.open_popup()
        return
    endif

    let git = gitmessenger#git#new(g:git_messenger_git_command)
    let args = ['--no-pager', 'log', '-n', '1', '--pretty=format:%b', hash]
    let cwd = fnamemodify(self.file, ':p:h')
    call git.spawn(args, cwd, funcref('s:blame__after_log', [], self))
endfunction

function! s:blame__start() dict abort
    let args = ['--no-pager', 'blame', self.file, '-L', self.line . ',+1', '--porcelain']
    let cwd = fnamemodify(self.file, ':p:h')
    let git = gitmessenger#git#new(g:git_messenger_git_command)
    call git.spawn(args, cwd, funcref('s:blame__after_blame', [], self))
endfunction
let s:blame.start = funcref('s:blame__start')

" file: string
" line: number
" opts: {
"   did_open: (b: Blame) => void
"   did_close: (p: Popup) => void
" }
function! gitmessenger#blame#new(file, line, opts) abort
    let b = deepcopy(s:blame)
    let b.line = a:line
    let b.file = a:file
    let b.opts = a:opts
    let b.index = 0
    let b.history = []
    return b
endfunction
