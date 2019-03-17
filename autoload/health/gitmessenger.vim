function! s:check_job() abort
    if !has('nvim') && !has('job')
        call health#report_error('Not supported since +job feature is not enabled')
    else
        call health#report_ok('+job is available to execute Git command')
    endif
endfunction

function! s:check_floating_window() abort
    if !has('nvim')
        return
    endif

    " XXX: Temporary
    if exists('*nvim_open_win') && !exists('*nvim_win_set_config')
        call health#report_error('Your Neovim is slightly older. Please update your Neovim to HEAD of 0.4.0-dev')
        return
    endif

    if !exists('*nvim_win_set_config')
        call health#report_warn('Neovim 0.3.0 or earlier does not support floating window feature. Preview window is used instead', 'Please install Neovim 0.4.0 or later')
    else
        call health#report_ok('Floating window is available for popup window')
    endif
endfunction

function! s:check_git_binary() abort
    let cmd = 'git'
    let cmd = get(g:, 'git_messenger_git_command', 'git')
    if !executable(cmd)
        call health#report_error('`' . cmd . '` command is not found. Please set proper command to g:git_messenger_git_command')
        return
    endif

    let output = substitute(system(cmd . ' --version'), '\n', '', 'g')
    if v:shell_error
        call health#report_error('Git command `' . cmd . '` is broken: ' . output)
        return
    endif

    call health#report_ok('Git command `' . cmd . '` is available: ' . output)
endfunction

function! health#gitmessenger#check() abort
    call s:check_job()
    call s:check_git_binary()
    call s:check_floating_window()
endfunction
