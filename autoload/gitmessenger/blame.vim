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

    let opts = { 'filetype': 'gitmessengerpopup' }
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif

    let self.popup = gitmessenger#popup#new(self.contents, opts)
    call self.popup.open()

    if has_key(self.opts, 'did_open')
        call self.opts.did_open(self)
    endif
endfunction

function! s:blame__after_blame(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        throw s:git_cmd_failure(a:git)
    endif

    " Parse `blame --porcelain` output
    let stdout = a:git.stdout
    let hash = matchstr(stdout[0], '^\S\+')
    let author = matchstr(stdout[1], '^author \zs.\+')
    let author_email = matchstr(stdout[2], '^author-email \zs\S\+')
    let self.contents = [
        \   '',
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

    " TODO: Check hash is 0000000000000000000000 it means that the line is not
    " commited yet

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
    let b.contents = []
    return b
endfunction
