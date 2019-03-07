let s:git = {}

function! s:on_output(job, data, event) dict abort
    if a:data == ['']
        return
    endif
    let self[a:event][-1] .= a:data[0]
    call extend(self[a:event], a:data[1:])
endfunction

function! s:on_exit(job, code, event) dict abort
    let self.exit_status = a:code
    call self.on_exit(self)
endfunction

function! s:git__spawn(args, cwd, on_exit) dict abort
    let cmdline = [self.cmd] + a:args
    let self.stdout = ['']
    let self.stderr = ['']
    let job_id = jobstart(cmdline, {
                \   'cwd': a:cwd,
                \   'on_stdout' : funcref('s:on_output', [], self),
                \   'on_exit' : funcref('s:on_exit', [], self),
                \ })
    if job_id == 0
        throw 'gitmessenger: Invalid arguments: ' . string(a:args)
    elseif job_id == -1
        throw 'gitmessenger: Command does not exist: ' . self.cmd
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
