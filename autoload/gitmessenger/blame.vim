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

function! s:blame__render() dict abort
    let self.popup.contents = self.contents
    call self.popup.update()
endfunction
let s:blame.render = funcref('s:blame__render')

function! s:blame__back() dict abort
    let next_index = self.index + 1

    call self.save_history()

    if len(self.history) > next_index
        call self.load_history(next_index)
        return
    endif

    if self.prev_commit ==# '' || self.oldest_commit =~# '^0\+$'
        echo 'git-messenger: No older commit found'
        return
    endif

    " Reset current state
    let self.diff = 'none'

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

    call self.save_history()
    call self.load_history(next_index)
endfunction
let s:blame.forward = funcref('s:blame__forward')

function! s:blame__load_history(index) dict abort
    let h = self.history[a:index]
    " Note: copy() is necessary because the contents may be updated later
    " for diff. Without copy(), it modifies array in self.history directly
    " but that's not intended.
    let self.contents = copy(h.contents)
    let self.diff = h.diff
    let self.commit = h.commit
    let self.index = a:index
    call self.render()
endfunction
let s:blame.load_history = funcref('s:blame__load_history')

function! s:blame__create_history() dict abort
    " Note: copy() is necessary because the contents may be updated later
    " for diff
    let self.history += [{
        \   'contents': copy(self.contents),
        \   'diff': self.diff,
        \   'commit': self.commit,
        \}]
endfunction
let s:blame.create_history = funcref('s:blame__create_history')

function! s:blame__save_history() dict abort
    if self.index > len(self.history)
        let msg = printf('FATAL: Invariant error on saving history. Index %d is out of range. Length of history is %d', self.index, len(self.history))
        call self.error(msg)
        return
    endif

    let h = self.history[self.index]
    if self.commit !=# h.commit
        call self.error(printf('FATAL: Invaliant error on saving history. Current commit hash %s is different from commit hash in history %s', self.commit, h.commit))
        return
    endif

    let h.diff = self.diff
    let h.contents = copy(self.contents)
endfunction
let s:blame.save_history = funcref('s:blame__save_history')

function! s:blame__open_popup() dict abort
    if has_key(self, 'popup') && has_key(self.popup, 'bufnr')
        " Already popup is open. It means that now older commit is showing up.
        " Save the contents to history and show the contents in current
        " popup.
        call self.create_history()
        let self.index = len(self.history) - 1
        call self.render()
        return
    endif

    let opts = {
        \   'filetype': 'gitmessengerpopup',
        \   'mappings': {
        \       'q': [{-> execute('close', '')}, 'Close popup window'],
        \       'o': [funcref(self.back, [], self), 'Back to older commit'],
        \       'O': [funcref(self.forward, [], self), 'Forward to newer commit'],
        \       'd': [funcref(self.reveal_diff, [v:false], self), "Toggle current file's diffs of current commit"],
        \       'D': [funcref(self.reveal_diff, [v:true], self), 'Toggle all diffs of current commit'],
        \   },
        \ }
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif
    if has_key(self.opts, 'enter_popup')
        let opts.enter = self.opts.enter_popup
    endif

    call self.create_history()
    let self.popup = gitmessenger#popup#new(self.contents, opts)
    call self.popup.open()

    if has_key(self.opts, 'did_open')
        call self.opts.did_open(self)
    endif
endfunction
let s:blame.open_popup = funcref('s:blame__open_popup')

function! s:blame__append_lines(lines) dict abort
    let lines = a:lines
    if lines[-1] ==# ''
        " Strip last newline
        let lines = lines[:-2]
    endif

    let skip_first_nl = v:true
    for line in lines
        if skip_first_nl && line ==# ''
            continue
        else
            let skip_first_nl = v:false
        endif

        if line ==# ''
            let self.contents += ['']
        else
            let self.contents += [' ' . line]
        endif
    endfor

    if self.contents[-1] !~# '^\s*$'
        let self.contents += ['']
    endif
endfunction
let s:blame.append_lines = funcref('s:blame__append_lines')

function! s:blame__after_diff(next_diff, git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    if a:git.stdout == [''] || !has_key(self.popup, 'bufnr') || bufnr('%') != self.popup.bufnr
        return
    endif

    call self.append_lines(a:git.stdout)

    call self.render()
    let self.diff = a:next_diff
endfunction

function! s:blame__reveal_diff(include_all) dict abort
    if a:include_all
        let next_diff = 'all'
    else
        let next_diff = 'current'
    endif

    if self.diff ==# next_diff
        " Toggle diff
        let next_diff = 'none'
    endif

    " Remove diff hunks from popup
    let saved = getpos('.')
    keepjumps execute 1
    let diff_start = search('^ diff --git ', 'ncW')
    if diff_start > 1
        let self.contents = self.contents[ : diff_start-2]
    endif
    keepjumps call setpos('.', saved)

    if next_diff ==# 'none'
        call self.render()
        let self.diff = next_diff
        return
    endif

    let hash = self.commit
    if hash ==# '' || hash =~# '^0\+$'
        call self.error('Not a valid commit hash: ' . hash)
        return
    endif

    let args = ['--no-pager', 'diff', hash . '^..' . hash]
    if !a:include_all
        let args += [self.file]
    endif
    let cwd = fnamemodify(self.file, ':p:h')
    let git = gitmessenger#git#new(g:git_messenger_git_command)
    call git.spawn(args, cwd, funcref('s:blame__after_diff', [next_diff], self))
endfunction
let s:blame.reveal_diff = funcref('s:blame__reveal_diff')

function! s:blame__after_log(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    if a:git.stdout != ['']
        call self.append_lines(a:git.stdout)
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
        call self.error('Unexpected `git blame` output: ' . join(stdout, '\n'))
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
    if exists('*strftime')
        let author_time = matchstr(stdout[3], '^author-time \zs\d\+')
        let self.contents += [' Date: ' . strftime('%c', str2nr(author_time))]
    endif
    let summary = matchstr(stdout[9], '^summary \zs.*')
    let prev_hash = matchstr(stdout[10], '^previous \zs[[:xdigit:]]\+')
    let self.contents += ['', ' ' . summary, '']

    let self.oldest_commit = hash
    let self.prev_commit = prev_hash
    let self.commit = hash

    " Check hash is 0000000000000000000000 it means that the line is not committed yet
    if hash =~# '^0\+$'
        call self.open_popup()
        return
    endif

    let args = ['--no-pager', 'log', '-n', '1', '--pretty=format:%b']
    if g:git_messenger_include_diff !=? 'none'
        if g:git_messenger_include_diff ==? 'current'
            let self.diff = 'current'
        else
            let self.diff = 'all'
        endif
        let args += ['-p', '-m']
    endif
    let args += [hash]
    if g:git_messenger_include_diff ==? 'current'
        let args += [self.file]
    endif

    call self.spawn_git(args, 's:blame__after_log')
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

" file: string;
" line: number;
" opts: {
"   did_open: (b: Blame) => void;
"   did_close: (p: Popup) => void;
"   on_error: (errmsg: string) => void;
"   enter_popup: boolean;
" };
" index: number;
" history: {
"   contents: string[];
"   diff: 'none' | 'all' | 'current';
"   commit: string;
" }[];
" diff: 'none' | 'all' | 'current';
" commit: string;
function! gitmessenger#blame#new(file, line, opts) abort
    let b = deepcopy(s:blame)
    let b.line = a:line
    let b.file = a:file
    let b.opts = a:opts
    let b.index = 0
    let b.history = []
    let b.diff = 'none'
    let b.commit = ''
    return b
endfunction
