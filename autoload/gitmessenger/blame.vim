let s:blame = {}

function! s:git_cmd_failure(git) abort
    return printf(
        \   'git-messenger: %s: `%s %s` exited with non-zero status %d',
        \   join(a:git.stderr, ' '),
        \   a:git.cmd,
        \   join(a:git.args, ' '),
        \   a:git.exit_status
        \ )
endfunction

function! s:blame__error(msg) dict abort
    if has_key(self.opts, 'on_error')
        call self.opts.on_error(a:msg)
    else
        throw a:msg
    endif
endfunction
let s:blame.error = funcref('s:blame__error')

function! s:blame__back() dict abort
    let next_index = self.index + 1

    if len(self.history) > next_index
        let self.index = next_index
        let self.contents = self.history[next_index]
        let self.popup.contents = self.contents
        call self.popup.update()
        return
    endif

    if self.prev_commit ==# '' || self.oldest_commit =~# '^0\+$'
        echo 'git-messenger: No older commit found'
        return
    endif

    let args = ['--no-pager', 'blame', self.prev_commit, self.file, '-L', self.line . ',+1', '--porcelain']
    let cwd = fnamemodify(self.file, ':p:h')
    let git = gitmessenger#git#new(g:git_messenger_git_command)
    call git.spawn(args, cwd, funcref('s:blame__after_blame', [], self))
endfunction
let s:blame.back = funcref('s:blame__back')

function! s:blame__forward() dict abort
    let next_index = self.index - 1
    if next_index < 0
        echo 'git-messenger: The latest commit'
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
        \       'q': [{-> execute('close', '')}, 'Close popup window'],
        \       'o': [funcref(self.back, [], self), 'Back to older commit'],
        \       'O': [funcref(self.forward, [], self), 'Forward to newer commit'],
        \   },
        \ }
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif
    if has_key(self.opts, 'enter_popup')
        let opts.enter = self.opts.enter_popup
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
        call self.error(s:git_cmd_failure(a:git))
        return
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
            echo 'git-messenger: ' . get(self, 'oldest_commit', 'It') . ' is the oldest commit'
            return
        endif
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    " Parse `blame --porcelain` output
    let stdout = a:git.stdout
    if len(stdout) < 10
        " Note: '\n' is not "\n", it's intentional
        call self.error("Unexpected `git blame` output: " . join(stdout, '\n'))
        return
    endif

    let hash = matchstr(stdout[0], '^\S\+')
    if has_key(self, 'oldest_commit') && self.oldest_commit ==# hash
        echo 'git-messenger: ' . hash . ' is the oldest commit'
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
    let prev_hash = matchstr(stdout[10], '^previous \zs[[:xdigit:]]\+')
    let self.contents += ['', ' ' . summary, '']

    let self.oldest_commit = hash
    let self.prev_commit = prev_hash

    " Check hash is 0000000000000000000000 it means that the line is not committed yet
    if hash =~# '^0\+$'
        call self.open_popup()
        return
    endif

    call self.spawn_git(['--no-pager', 'log', '-n', '1', '--pretty=format:%b', hash], 's:blame__after_log')
endfunction

function! s:blame__spawn_git(args, callback) dict abort
    let cwd = fnamemodify(self.file, ':p:h')
    let git = gitmessenger#git#new(g:git_messenger_git_command)
    try
        call git.spawn(a:args, cwd, funcref(a:callback, [], self))
    catch /^git-messenger: /
        call self.error(v:exception)
    endtry
endfunction
let s:blame.spawn_git = funcref('s:blame__spawn_git')

function! s:blame__start() dict abort
    call self.spawn_git(
        \ ['--no-pager', 'blame', self.file, '-L', self.line . ',+1', '--porcelain'],
        \ 's:blame__after_blame')
endfunction
let s:blame.start = funcref('s:blame__start')

" file: string
" line: number
" opts: {
"   did_open: (b: Blame) => void;
"   did_close: (p: Popup) => void;
"   on_error: (errmsg: string) => void;
"   enter_popup: boolean;
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
