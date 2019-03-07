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
        call gitmessenger#legacy#echo()
        let s:prev_line = line('.')
        autocmd! GitMessenger CursorMoved,CursorMovedI * 
                    \  if s:prev_line != line('.')
                    \|     call gitmessenger#legacy#echo()
                    \|     let s:prev_line = line('.')
                    \| endif
    endif
    let s:gitmessenger_is_running = ! s:gitmessenger_is_running
endfunction

command! -nargs=0 GitMessengerToggle call GitMessengerToggle()

function! GitMessengerBalloonToggle()
    if empty(&balloonexpr)
        " not active
        set balloonexpr=gitmessenger#legacy#balloon_expr()
        set ballooneval
    else
        " active
        set noballooneval
        set balloonexpr=
    endif
endfunction

command! -nargs=0 GitMessengerBalloonToggle call GitMessengerBalloonToggle()

nnoremap <silent><Plug>(git-messenger-commit-summary) :<C-u>call gitmessenger#legacy#echo()<CR>
nnoremap <silent><Plug>(git-messenger-commit-message) :<C-u>echo gitmessenger#legacy#commit_message(expand('%'), line('.'))<CR>

" Next

command! -nargs=0 -bar GitMessenger call gitmessenger#new(expand('%:p'), line('.'), bufnr('%'), {'close_on_cursor_moved': v:true})
command! -nargs=0 -bar GitMessengerClose call gitmessenger#close_popup(bufnr('%'))

nnoremap <silent><Plug>(git-messenger) :<C-u>call gitmessenger#new(expand('%:p'), line('.'), bufnr('%'), {'close_on_cursor_moved': v:true})<CR>
nnoremap <silent><Plug>(git-messenger-close) :<C-u>call gitmessenger#close_popup(bufnr('%'))<CR>
nnoremap <silent><Plug>(git-messenger-into-popup) :<C-u>call gitmessenger#into_popup(bufnr('%'))<CR>
nnoremap <silent><Plug>(git-messenger-scroll-down-1) :<C-u>call gitmessenger#scroll(bufnr('%'), 'C-e')<CR>
nnoremap <silent><Plug>(git-messenger-scroll-up-1) :<C-u>call gitmessenger#scroll(bufnr('%'), 'C-y')<CR>
nnoremap <silent><Plug>(git-messenger-scroll-down-page) :<C-u>call gitmessenger#scroll(bufnr('%'), 'C-f')<CR>
nnoremap <silent><Plug>(git-messenger-scroll-up-page) :<C-u>call gitmessenger#scroll(bufnr('%'), 'C-b')<CR>

if !exists('g:git_messenger_no_default_mappings')
    nmap <Leader>gm <Plug>(git-messenger)
endif
