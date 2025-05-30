let s:SEP = has('win32') ? '\' : '/'

function! s:find_gitdir(from) abort
    let dir = finddir('.git', a:from . ';')
    let file = findfile('.git', a:from . ';')

    if dir ==# '' && file ==# ''
        return ''
    endif

    " When .git directory is below the current working directory, finddir()
    " returns a relative path. So ensuring an absolute path here.
    let dir = dir ==# '' ? '' : fnamemodify(dir, ':p')

    " When .git exists in current directory, findfile() returns relative path
    " '.git' though finddir() returns an absolute path '/path/to/.git' (#49).
    " Since path length will be compared, they must be both abusolute path.
    let file = file ==# '' ? '' : fnamemodify(file, ':p')

    " Choose larger (deeper) path (#48). When worktree directory is put in its
    " main repository, the .git directory which is near to `from` should be
    " chosen.
    " When `dir` or `file` is empty, the other is chosen so we don't need to
    " care about empty string here.
    let gitdir = len(dir) > len(file) ? dir : file

    " Inside .git directory is outside repository
    " This check must be done before chopping last path separator otherwise it
    " matches to directory like /path/to/.github/ (#70)
    if stridx(a:from, gitdir) == 0
        return ''
    endif

    if gitdir[-1:] ==# s:SEP
        " [:-2] chops last path separator (/path/to/.git/ => /path/to/.git)
        let gitdir = gitdir[:-2]
    endif

    return gitdir
endfunction

" Params:
"   path: string
"     base path to find .git in ancestor directories
" Returns:
"   string
"     empty string means git dir was not found
function! gitmessenger#git#gitdir(from) abort
    let from = fnameescape(fnamemodify(a:from, ':p'))
    if from[-1:] ==# s:SEP
        " [:-2] chops last path separator
        let from = from[:-2]
    endif
    let gitdir = s:find_gitdir(from)

    return gitdir
endfunction

let s:git = {}

if has('nvim')
    function! s:on_output_nvim(job, data, event) dict abort
        if a:data == ['']
            return
        endif
        " Output from Git might contain \r for example when the commit
        " author's text editor uses \r\n for newlines. But Neovim reads output
        " from the process line by line based on \n. The trailing \r remains
        " when \r\n is used for newlines. This removes the trailing \r (#75).
        call map(a:data, 'v:val[len(v:val)-1] ==# "\r" ? v:val[:-2] : v:val')
        let self[a:event][-1] .= a:data[0]
        call extend(self[a:event], a:data[1:])
    endfunction

    function! s:on_exit_nvim(job, code, event) dict abort
        let self.exit_status = a:code
        call self.on_exit(self)
    endfunction
else
    function! s:git__finalize_vim(ch) dict abort
        if has_key(self, 'finalized') && self.finalized
            return
        endif

        " Note:
        " Workaround for Vim's exit_cb behavior. When the callback is called,
        " sometimes channel for stdout and/or stderr is not closed yet. So
        " their status may be 'open'. As workaround for the behavior, we do
        " polling to check the channel statuses with 1 msec interval until the
        " statuses are set to 'close'. (#16)
        let out_opt = {'part': 'out'}
        let err_opt = {'part': 'err'}
        while 1
            let out_status = ch_status(a:ch, out_opt)
            let err_status = ch_status(a:ch, err_opt)
            if out_status !=# 'open' && out_status !=# 'buffered' &&
             \ err_status !=# 'open' && err_status !=# 'buffered'
                let self.finalized = v:true
                call self.on_exit(self)
                return
            endif
            sleep 1m
        endwhile
    endfunction
    let s:git.finalize_vim = funcref('s:git__finalize_vim')

    function! s:on_output_vim(event, ch, msg) dict abort
        call extend(self[a:event], split(a:msg, '\r\=\n', 1))
    endfunction

    function! s:on_exit_vim(ch, code) dict abort
        let self.exit_status = a:code
        call self.finalize_vim(a:ch)
    endfunction
endif

" Params:
"   args: string[]
"   on_exit: (git: Git) => void
" Returns:
"   Job ID of the spawned process
function! s:git__spawn(args, on_exit) dict abort
    let cmdline = [self.cmd, '--git-dir', self.gitdir, '--work-tree', self.worktree] + a:args
    if has('nvim')
        let self.stdout = ['']
        let self.stderr = ['']
        let job_id = jobstart(cmdline, {
                    \   'cwd': self.worktree,
                    \   'on_stdout' : funcref('s:on_output_nvim', [], self),
                    \   'on_stderr' : funcref('s:on_output_nvim', [], self),
                    \   'on_exit' : funcref('s:on_exit_nvim', [], self),
                    \ })
        if job_id == 0
            throw 'git-messenger: Invalid arguments: ' . string(a:args)
        elseif job_id == -1
            throw 'git-messenger: Command does not exist: ' . self.cmd
        endif
    else
        let self.stdout = []
        let self.stderr = []
        let job_id = job_start(cmdline, {
                    \   'cwd': self.worktree,
                    \   'out_cb' : funcref('s:on_output_vim', ['stdout'], self),
                    \   'err_cb' : funcref('s:on_output_vim', ['stderr'], self),
                    \   'exit_cb' : funcref('s:on_exit_vim', [], self),
                    \ })
    endif
    let self.job_id = job_id
    let self.on_exit = a:on_exit
    let self.args = a:args
    return job_id
endfunction
let s:git.spawn = funcref('s:git__spawn')

" Creates new Git instance. Git instance represents one-shot Git command
" asynchronous execution.
"
" Params:
"   cmd: string
"     'git' command to run Git
"   dir: string
"     Directory path to run Git
" Returns:
"   Git object
function! gitmessenger#git#new(cmd, gitdir, worktree) abort
    let g = deepcopy(s:git)
    let g.cmd = a:cmd
    let g.gitdir = a:gitdir
    let g.worktree = a:worktree
    return g
endfunction
