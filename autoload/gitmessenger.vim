let s:all_popup = {}

function! s:on_cursor_moved() abort
    let bufnr = bufnr('%')
    if !has_key(s:all_popup, bufnr)
        autocmd! plugin-git-messenger-close * <buffer>
        return
    endif
    let popup = s:all_popup[bufnr]
    if popup.opened_at != getpos('.')
        autocmd! plugin-git-messenger-close * <buffer>
        call gitmessenger#close_popup(bufnr)
    endif
endfunction

function! s:on_open(blame) dict abort
    if !has_key(a:blame.popup, 'bufnr')
        " For some reason, popup was already closed
        return
    endif
    let opener_bufnr = a:blame.popup.opener_bufnr
    let s:all_popup[opener_bufnr] = a:blame.popup
    if has_key(self, 'close_on_cursor_moved') && self.close_on_cursor_moved
        augroup plugin-git-messenger-close
            autocmd CursorMoved,CursorMovedI <buffer> call <SID>on_cursor_moved()
        augroup END
    endif
endfunction

function! s:on_close(popup) dict abort
    unlet! s:all_popup[a:popup.opener_bufnr]
endfunction

" file: string
" line: number
" bufnr: number
" opts?: {
"   close_on_cursor_moved?: boolean;
" }
function! gitmessenger#new(file, line, bufnr, ...) abort
    let opts = get(a:, 1, {})
    let opts.pos = getpos('.')
    " Close previous popup
    if has_key(s:all_popup, a:bufnr)
        call s:all_popup[a:bufnr].close()
        unlet! s:all_popup[a:bufnr]
    endif

    let blame = gitmessenger#blame#new(a:file, a:line, {
            \   'did_open': funcref('s:on_open', [], opts),
            \   'did_close': funcref('s:on_close', [], opts),
            \ })
    call blame.start()
endfunction

function! gitmessenger#close_popup(bufnr) abort
    if !has_key(s:all_popup, a:bufnr)
        echo 'No popup found'
        return
    endif
    call s:all_popup[a:bufnr].close()
endfunction
