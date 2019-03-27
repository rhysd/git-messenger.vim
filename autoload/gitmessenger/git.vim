let s:git = {}

if has('nvim')
    function! s:on_output_nvim(job, data, event) dict abort
        if a:data == ['']
            return
        endif
        let self[a:event][-1] .= a:data[0]
        call extend(self[a:event], a:data[1:])
    endfunction

    function! s:on_exit_nvim(job, code, event) dict abort
        let self.exit_status = a:code
        call self.on_exit(self)
    endfunction
else
    function! s:git__may_finalize_vim(ch) dict abort
        if has_key(self, 'finalized') && self.finalized
            return
        endif
        if !has_key(self, 'exit_status')
            return
        endif
        let out_status = ch_status(a:ch, {'part': 'out'})
        let err_status = ch_status(a:ch, {'part': 'err'})
        if out_status !=# 'open' && out_status !=# 'buffered' &&
         \ err_status !=# 'open' && err_status !=# 'buffered'
            let self.finalized = v:true
            call self.on_exit(self)
        endif
    endfunction
    let s:git.may_finalize_vim = funcref('s:git__may_finalize_vim')

    function! s:on_output_vim(event, ch, msg) dict abort
        call extend(self[a:event], split(a:msg, "\n", 1))
        call self.may_finalize_vim(a:ch)
    endfunction

    function! s:on_exit_vim(ch, code) dict abort
        let self.exit_status = a:code
        call self.may_finalize_vim(a:ch)
    endfunction
endif

function! s:git__spawn(args, cwd, on_exit) dict abort
    let cmdline = [self.cmd] + a:args
    if has('nvim')
        let self.stdout = ['']
        let self.stderr = ['']
        let job_id = jobstart(cmdline, {
                    \   'cwd': a:cwd,
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
                    \   'cwd': a:cwd,
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

function! gitmessenger#git#new(cmd) abort
    let g = deepcopy(s:git)
    let g.cmd = a:cmd
    return g
endfunction
