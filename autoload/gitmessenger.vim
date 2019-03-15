" All popup instances keyed by opener's bufnr to manage lifetime of popups
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

function! s:on_buf_enter(bufnr) abort
    let popup = s:popup_for(a:bufnr)

    if popup is v:null
        autocmd! plugin-git-messenger-buf-enter
        return
    endif

    let b = bufnr('%')
    " When entering/exiting popup window, do nothing
    if popup.bufnr == b || popup.opener_bufnr == b
        " Note: Do not close popup when cursor moves into opener buffer.
        " Otherwise, it accidentally closes the popup when updating the window
        " for jumping to older commits.
        return
    endif

    " This triggers s:on_close()
    call popup.close()

    if empty(s:all_popup)
        autocmd! plugin-git-messenger-buf-enter
    endif
endfunction

function! s:on_open(blame) dict abort
    if !has_key(a:blame.popup, 'bufnr')
        " For some reason, popup was already closed
        unlet! a:all_popup[a:blame.popup.opener_bufnr]
        return
    endif

    let opener_bufnr = a:blame.popup.opener_bufnr
    let s:all_popup[opener_bufnr] = a:blame.popup

    if get(self, 'close_on_cursor_moved', 1)
        augroup plugin-git-messenger-close
            autocmd CursorMoved,CursorMovedI,InsertEnter <buffer> call <SID>on_cursor_moved()
        augroup END
    endif

    augroup plugin-git-messenger-buf-enter
        execute 'autocmd BufEnter * call <SID>on_buf_enter(' . opener_bufnr . ')'
    augroup END
endfunction

function! s:on_close(popup) dict abort
    unlet! s:all_popup[a:popup.opener_bufnr]
endfunction

function! s:on_error(errmsg) abort
    echohl ErrorMsg
    " Avoid ^@
    for line in split(a:errmsg, "\n")
        echomsg line
    endfor
    echohl None
endfunction

" file: string
" line: number
" bufnr: number
" opts?: {
"   close_on_cursor_moved?: boolean;
" }
function! gitmessenger#new(file, line, bufnr, ...) abort
    " When cursor is in popup window, close the window
    if gitmessenger#popup#close_current_popup()
        return
    endif

    " Just after opening a popup window, move cursor into the window
    if g:git_messenger_into_popup_after_show && has_key(s:all_popup, a:bufnr)
        let p = s:all_popup[a:bufnr]
        if has_key(p, 'bufnr')
            call p.into()
            return
        endif
    endif

    let opts = get(a:, 1, {})
    let opts.pos = getpos('.')
    " Close previous popup
    if has_key(s:all_popup, a:bufnr)
        call s:all_popup[a:bufnr].close()
    endif

    let blame = gitmessenger#blame#new(a:file, a:line, {
            \   'did_open': funcref('s:on_open', [], opts),
            \   'did_close': funcref('s:on_close', [], opts),
            \   'on_error': funcref('s:on_error'),
            \   'enter_popup': g:git_messenger_always_into_popup,
            \ })
    call blame.start()
endfunction

function! s:popup_for(bufnr) abort
    if !has_key(s:all_popup, a:bufnr)
        return v:null
    endif

    let popup = s:all_popup[a:bufnr]
    if !has_key(popup, 'bufnr')
        " Here should be unreachable
        unlet! s:all_popup[a:bufnr]
        return v:null
    endif

    return popup
endfunction

function! gitmessenger#close_popup(bufnr) abort
    if gitmessenger#popup#close_current_popup()
        return
    endif
    let p = s:popup_for(a:bufnr)
    if p isnot v:null
        call p.close()
    endif
endfunction

function! gitmessenger#scroll(bufnr, map) abort
    let p = s:popup_for(a:bufnr)
    if p isnot v:null
        call p.scroll(a:map)
    endif
endfunction

function! gitmessenger#into_popup(bufnr) abort
    let p = s:popup_for(a:bufnr)
    if p isnot v:null
        call p.into()
    endif
endfunction
