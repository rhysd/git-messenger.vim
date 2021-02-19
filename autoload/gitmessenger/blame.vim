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
    let self.popup.contents = self.state.contents
    if self.state.prev_diff !=# self.state.diff
        call self.popup.set_buf_var('__gitmessenger_diff', self.state.diff)
        let prev_is_word = self.state.prev_diff =~# '\.word$'
        let is_word = self.state.diff =~# '\.word$'
        if self.state.diff !=# 'none' && prev_is_word != is_word
            call self.popup.set_buf_var('&syntax', 'gitmessengerpopup')
        endif
    endif
    call self.popup.update()
endfunction
let s:blame.render = funcref('s:blame__render')

function! s:blame__back() dict abort
    if self.state.back()
        call self.render()
        return
    endif

    if self.prev_commit ==# '' || self.oldest_commit =~# '^0\+$'
        echo 'git-messenger: No older commit found'
        return
    endif

    " Reset current state
    call self.state.set_diff('none')

    let args = ['--no-pager', 'blame', self.prev_commit, '-L', self.line . ',+1', '--porcelain'] + split(g:git_messenger_extra_blame_args, ' ') + ['--', self.blame_file]
    call self.spawn_git(args, 's:blame__after_blame')
endfunction
let s:blame.back = funcref('s:blame__back')

function! s:blame__forward() dict abort
    if self.state.forward()
        call self.render()
    elseif self.state.commit !=# ''
        echo 'git-messenger: ' . self.state.commit . ' is the latest commit'
    else
        echo 'git-messenger: The latest commit'
    endif
endfunction
let s:blame.forward = funcref('s:blame__forward')

function! s:blame__open_popup() dict abort
    if has_key(self, 'popup') && has_key(self.popup, 'bufnr')
        " Already popup is open. It means that now older commit is showing up.
        " Save the contents to history and show the contents in current
        " popup.
        call self.state.push()
        call self.state.save()
        call self.render()
        return
    endif

    let opts = {
        \   'filetype': 'gitmessengerpopup',
        \   'mappings': {
        \       'q': [{-> execute('close', '')}, 'Close popup window'],
        \       'o': [funcref(self.back, [], self), 'Back to older commit'],
        \       'O': [funcref(self.forward, [], self), 'Forward to newer commit'],
        \       'd': [funcref(self.reveal_diff, [v:false, v:false], self), "Toggle current file's diffs of current commit"],
        \       'D': [funcref(self.reveal_diff, [v:true, v:false], self), 'Toggle all diffs of current commit'],
        \       'r': [funcref(self.reveal_diff, [v:false, v:true], self), "Toggle current file's word diffs of current commit"],
        \       'R': [funcref(self.reveal_diff, [v:true, v:true], self), 'Toggle all word diffs of current commit'],
        \   },
        \ }
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif
    if has_key(self.opts, 'enter_popup')
        let opts.enter = self.opts.enter_popup
    endif

    call self.state.push()
    let self.popup = gitmessenger#popup#new(self.state.contents, opts)
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
            let self.state.contents += ['']
        else
            let self.state.contents += [' ' . line]
        endif
    endfor

    if self.state.contents[-1] !~# '^\s*$'
        let self.state.contents += ['']
    endif
endfunction
let s:blame.append_lines = funcref('s:blame__append_lines')

function! s:blame__after_diff(next_diff, git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    let popup_open = has_key(self, 'popup')

    if a:git.stdout == [] || a:git.stdout == [''] ||
        \ (popup_open && !has_key(self.popup, 'bufnr'))
        return
    endif

    " When getting diff with `git show --pretty=format:%b`, it may contain
    " commit body. By removing line until 'diff --git ...' line, the body is
    " removed (#35)
    while a:git.stdout !=# [] && stridx(a:git.stdout[0], 'diff --git ') !=# 0
        let a:git.stdout = a:git.stdout[1:]
    endwhile

    call self.append_lines(a:git.stdout)
    call self.state.set_diff(a:next_diff)

    if popup_open
        call self.render()
    else
        " Note: When g:git_messenger_include_diff is not 'none' and popup is
        " being opened for line which is not committed yet.
        " In the case, commit hash is 0000000000000000 and `git log` is not
        " available. So `git diff` is used instead and this callback is
        " called.
        call self.open_popup()
    endif
endfunction

function! s:blame__reveal_diff(include_all, word_diff) dict abort
    if a:include_all
        let next_diff = 'all'
    else
        let next_diff = 'current'
    endif
    if a:word_diff
        let next_diff .= '.word'
    endif

    if self.state.diff ==# next_diff
        " Toggle diff
        let next_diff = 'none'
    endif

    " Remove diff hunks from popup
    let saved = getpos('.')
    try
        keepjumps execute 1
        let diff_start = search('^ diff --git ', 'ncW')
        if diff_start > 1
            let self.state.contents = self.state.contents[ : diff_start-2]
        endif
    finally
        keepjumps call setpos('.', saved)
    endtry

    if next_diff ==# 'none'
        let self.state.diff = next_diff
        call self.render()
        return
    endif

    let hash = self.state.commit
    if hash ==# ''
        call self.error('Not a valid commit hash: ' . hash)
        return
    endif
    if hash !~# '^0\+$'
        " `git diff hash^..hash` is not available since hash^ is invalid when
        " it is an initial commit.
        let args = ['--no-pager', 'show', '--no-color', '--pretty=format:%b', hash]
    else
        " When the line is not committed yet, show diff against HEAD (#26)
        let args = ['--no-pager', 'diff', '--no-color', 'HEAD']
    endif

    if a:word_diff
        let args += ['--word-diff=plain']
    endif

    if !a:include_all
        let args += ['--', self.state.diff_file_to]
        let prev = self.state.diff_file_from
        if prev !=# '' && prev != self.state.diff_file_to
            " Note: When file was renamed, both file name before rename and file
            " name after rename are necessary to show correct diff.
            " If only file name after rename is specified, it shows diff as if
            " the file was added at the commit not considering rename.
            let args += [prev]
        endif
    endif
    call self.spawn_git(args, funcref('s:blame__after_diff', [next_diff], self))
endfunction
let s:blame.reveal_diff = funcref('s:blame__reveal_diff')

function! s:blame__after_log(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    if a:git.stdout != [] && a:git.stdout != ['']
        call self.append_lines(a:git.stdout)
    endif

    call self.open_popup()
endfunction

function! s:blame__after_blame(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        if a:git.stderr[0] =~# 'has only \d\+ lines\='
            echo 'git-messenger: ' . get(self, 'oldest_commit', 'It') . ' is the oldest commit'
            return
        endif
        call self.error(s:git_cmd_failure(a:git))
        return
    endif

    " Parse `blame --porcelain` output
    " Note: Output less than 11 lines are invalid. At least followings should
    " be included:
    "   header, author, author-email, author-time, author-tz, committer-email,
    "   committer-time, committer-tz, summary, filename
    let stdout = a:git.stdout
    if len(stdout) < 11
        " Note: '\n' is not "\n", it's intentional
        call self.error('Unexpected `git blame` output: ' . join(stdout, '\n'))
        return
    endif

    " Blame header
    " {hash} {line number of original} {line number of final} {line offset in lines group}
    "
    "   Please see 'THE PORCELAIN FORMAT' section of `man git-blame` for more
    "   details
    let hash = matchstr(stdout[0], '^[[:xdigit:]]\+')
    if has_key(self, 'oldest_commit') && self.oldest_commit ==# hash
        echo 'git-messenger: ' . hash . ' is the oldest commit'
        return
    endif
    let not_committed_yet = hash =~# '^0\+$'

    let author = matchstr(stdout[1], '^author \zs.\+')
    let author_email = matchstr(stdout[2], '^author-mail \zs\S\+')
    let committer = matchstr(stdout[5], '^committer \zs.\+')
    let headers = [
        \   ['History', '#' . self.state.history_no()],
        \   ['Commit', hash],
        \   ['Author', author . ' ' . author_email],
        \ ]

    if author !=# committer
        let committer_email = matchstr(stdout[6], '^committer-mail \zs\S\+')
        let headers += [['Committer', committer . ' ' . committer_email]]
    endif

    if exists('*strftime')
        let author_time = matchstr(stdout[3], '^author-time \zs\d\+')
        let committer_time = matchstr(stdout[7], '^committer-time \zs\d\+')
        if author_time ==# committer_time
            let headers += [['Date', strftime(g:git_messenger_date_format, str2nr(author_time))]]
        else
            let headers += [['Author Date', strftime(g:git_messenger_date_format, str2nr(author_time))]]
            let headers += [['Committer Date', strftime(g:git_messenger_date_format, str2nr(committer_time))]]
        endif
    endif

    let header_width = 0
    for [key, _] in headers
        let len = len(key)
        if len > header_width
            let header_width = len
        endif
    endfor

    let self.state.contents = ['']
    for [key, value] in headers
        let pad = repeat(' ', header_width - len(key))
        let line = printf(' %s: %s%s', key, pad, value)
        let self.state.contents += [line]
    endfor

    if not_committed_yet
        let summary = 'This line is not committed yet'
    else
        let summary = matchstr(stdout[9], '^summary \zs.*')
    endif
    let self.state.contents += ['', ' ' . summary, '']

    " Reset the state
    let self.prev_commit = ''
    let self.blame_file = ''
    " Diff target file is fallback to blame target file
    let self.state.diff_file_to = self.blame_file

    " Parse 'previous', 'boundary' and 'filename'
    for line in stdout[10:]
        " At final of output, the current line prefixed with tab is put
        if line[0] ==# "\t"
            break
        endif

        " previous {hash} {next blame file path}
        "
        "   where {next blame file path} is a relative path from root directory of
        "   the repository.
        let m = matchlist(line, '^previous \([[:xdigit:]]\+\) \(.\+\)$')
        if m != []
            let self.prev_commit = m[1]
            let self.blame_file = m[2]
            continue
        endif

        " filename {file path from root dir}
        "
        "   where {file path} is a target file of the current commit.
        "   The file name may be different from current editing file because
        "   it might be renamed.
        let filename = matchstr(line, '^filename \zs.\+$')
        if filename !=# ''
            let self.state.diff_file_to = filename
            continue
        endif

        " boundary
        "   Boudary commit. It means current commit is the oldest.
        "   Nothing to do
    endfor

    " diff_file_from is the same as blame_file at this moment, but stored in
    " another variable since it should be stored in history.
    let self.state.diff_file_from = self.blame_file
    let self.oldest_commit = hash
    let self.state.commit = hash

    " Check hash is 0000000000000000000000 it means that the line is not committed yet
    if hash =~# '^0\+$'
        if g:git_messenger_include_diff ==? 'none'
            call self.open_popup()
            return
        endif

        " Note: To show diffs which are not committed yet, `git log` is not
        " available. Use `git diff` instead.
        let next_diff = 'all'
        let args = ['--no-pager', 'diff', 'HEAD']
        if g:git_messenger_include_diff ==? 'current'
            let next_diff = 'current'
            let args += [self.blame_file]
        endif
        call self.spawn_git(args, funcref('s:blame__after_diff', [next_diff], self))
        return
    endif

    let args = ['--no-pager', 'log', '--no-color', '-n', '1', '--pretty=format:%b']
    if g:git_messenger_include_diff !=? 'none'
        if g:git_messenger_include_diff ==? 'current'
            call self.state.set_diff('current')
        else
            call self.state.set_diff('all')
        endif
        let args += ['-p', '-m']
    endif
    let args += [hash]

    if g:git_messenger_include_diff ==? 'current'
        let args += ['--', self.state.diff_file_to]
        let prev = self.state.diff_file_from
        if prev !=# '' && prev != self.state.diff_file_to
            " Note: When file was renamed, both file name before rename and file
            " name after rename are necessary to show correct diff.
            " If only file name after rename is specified, it shows diff as if
            " the file was added at the commit not considering rename.
            let args += [prev]
        endif
    endif

    call self.spawn_git(args, 's:blame__after_log')
endfunction

function! s:blame__spawn_git(args, callback) dict abort
    let git = gitmessenger#git#new(g:git_messenger_git_command, self.git_root)
    let CB = a:callback
    if type(CB) == v:t_string
        let CB = funcref(CB, [], self)
    endif
    try
        call git.spawn(a:args, CB)
    catch /^git-messenger: /
        call self.error(v:exception)
    endtry
endfunction
let s:blame.spawn_git = funcref('s:blame__spawn_git')

function! s:blame__start() dict abort
    call self.spawn_git(
        \ ['--no-pager', 'blame', self.blame_file, '-L', self.line . ',+1', '--porcelain'] + split(g:git_messenger_extra_blame_args, ' '),
        \ 's:blame__after_blame')
endfunction
let s:blame.start = funcref('s:blame__start')

" interface Blame {
"   state: BlameHistory;
"   line: number;
"   git_root: string;
"   blame_file: string;
"   prev_commit?: string;
"   oldest_commit?: string;
"   opts: {
"     did_open: (b: Blame) => void;
"     did_close: (p: Popup) => void;
"     on_error: (errmsg: string) => void;
"     enter_popup: boolean;
"   };
" }
"
" blame_file:
"   File path given to `git blame`. This can be relative to root of repo.
"   Note: This does not need to be put in BlameHistory state because it is
"   used by only `git blame`.
function! gitmessenger#blame#new(file, line, opts) abort
    let b = deepcopy(s:blame)
    let b.state = gitmessenger#history#new(a:file)
    let b.line = a:line
    let b.blame_file = a:file
    let b.opts = a:opts

    let dir = fnamemodify(a:file, ':p:h')
    let b.git_root = gitmessenger#git#root_dir(dir)

    " Validations
    if b.git_root ==# ''
        call b.error("git-messenger: Directory '" . dir . "' is not inside a Git repository")
        return v:null
    endif

    return b
endfunction
