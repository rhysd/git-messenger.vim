if exists('g:loaded_gitmessenger')
    finish
endif
let g:loaded_gitmessenger = 1

let s:gitmessenger_is_running = 0
augroup GitMessenger
    autocmd!
augroup END

function! GitMessengerToggle()
    if s:gitmessenger_is_running
        autocmd! GitMessenger
    else
        call gitmessenger#echo()
        let s:prev_line = line('.')
        autocmd! GitMessenger CursorMoved,CursorMovedI * 
                    \  if s:prev_line != line('.')
                    \|     call gitmessenger#echo()
                    \|     let s:prev_line = line('.')
                    \| endif
    endif
    let s:gitmessenger_is_running = ! s:gitmessenger_is_running
endfunction

command! -nargs=0 GitMessengerToggle call GitMessengerToggle()

function! GitMessengerBalloonToggle()
    if empty(&balloonexpr)
        " not active
        set balloonexpr=gitmessenger#balloon_expr()
        set ballooneval
    else
        " active
        set noballooneval
        set balloonexpr=
    endif
endfunction

command! -nargs=0 GitMessengerBalloonToggle call GitMessengerBalloonToggle()

nnoremap <silent><Plug>(git-messenger-commit-summary) :<C-u>call gitmessenger#echo()<CR>
nnoremap <silent><Plug>(git-messenger-commit-message) :<C-u>echo gitmessenger#commit_message(expand('%'), line('.'))<CR>

