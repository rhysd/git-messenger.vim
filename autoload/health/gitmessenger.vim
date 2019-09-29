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

    if !exists('*nvim_win_set_config')
        call health#report_warn(
            \ 'Neovim 0.3.0 or earlier does not support floating window feature. Preview window is used instead',
            \ 'Please install Neovim 0.4.0 or later')
        return
    endif

    " XXX: Temporary
    try
        noautocmd let win_id = nvim_open_win(bufnr('%'), v:false, {
                    \   'relative': 'editor',
                    \   'row': 0,
                    \   'col': 0,
                    \   'width': 2,
                    \   'height': 2,
                    \ })
        noautocmd call nvim_win_close(win_id, v:true)
    catch /^Vim\%((\a\+)\)\=:E118/
        call health#report_error(
            \ 'Your Neovim is too old',
            \ [
            \   'Please update Neovim to 0.4.0 or later',
            \   'If the version does not fix the error, please make an issue at https://github.com/rhysd/git-messenger.vim',
            \ ])
        return
    endtry

    call health#report_ok('Floating window is available for popup window')
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

function! s:check_vim_version() abort
    if has('nvim')
        return
    endif

    if v:version < 800
        call health#report_error(
            \ 'Your Vim version is too old: ' . v:version,
            \ 'Please install Vim 8.0 or later')
        return
    endif

    call health#report_ok('Vim version is fine: ' . v:version)
endfunction

function! health#gitmessenger#check() abort
    call s:check_job()
    call s:check_git_binary()
    call s:check_floating_window()
    call s:check_vim_version()
endfunction
