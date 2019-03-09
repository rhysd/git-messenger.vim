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
            autocmd CursorMoved,CursorMovedI,InsertEnter <buffer> call <SID>on_cursor_moved()
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
        unlet! s:all_popup[a:bufnr]
    endif

    let blame = gitmessenger#blame#new(a:file, a:line, {
            \   'did_open': funcref('s:on_open', [], opts),
            \   'did_close': funcref('s:on_close', [], opts),
            \   'enter_popup': !g:git_messenger_always_into_popup,
            \ })
    call blame.start()
endfunction

function! s:popup_for(bufnr) abort
    if !has_key(s:all_popup, a:bufnr)
        echo 'No popup found'
        return v:null
    endif
    return s:all_popup[a:bufnr]
endfunction

function! gitmessenger#close_popup(bufnr) abort
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
