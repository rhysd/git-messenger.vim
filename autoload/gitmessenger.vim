" Global variables
let g:git_messenger_close_on_cursor_moved = get(g:, 'git_messenger_close_on_cursor_moved', v:true)
let g:git_messenger_git_command = get(g:, 'git_messenger_git_command', 'git')
let g:git_messenger_into_popup_after_show = get(g:, 'git_messenger_into_popup_after_show', v:true)
let g:git_messenger_always_into_popup = get(g:, 'git_messenger_always_into_popup', v:false)
let g:git_messenger_preview_mods = get(g:, 'git_messenger_preview_mods', '')
let g:git_messenger_extra_blame_args = get(g:, 'git_messenger_extra_blame_args', '')
let g:git_messenger_include_diff = get(g:, 'git_messenger_include_diff', 'none')
let g:git_messenger_max_popup_height = get(g:, 'git_messenger_max_popup_height', v:null)
let g:git_messenger_max_popup_width = get(g:, 'git_messenger_max_popup_width', v:null)
let g:git_messenger_date_format = get(g:, 'git_messenger_date_format', '%c')
let g:git_messenger_conceal_word_diff_marker = get(g:, 'git_messenger_conceal_word_diff_marker', 1)
let g:git_messenger_floating_win_opts = get(g:, 'git_messenger_floating_win_opts', {})
let g:git_messenger_popup_content_margins = get(g:, 'git_messenger_popup_content_margins', v:true)

" All popup instances keyed by opener's bufnr to manage lifetime of popups
let s:all_popups = {}

function! s:on_cursor_moved() abort
    let bufnr = bufnr('%')
    if !has_key(s:all_popups, bufnr)
        autocmd! plugin-git-messenger-close * <buffer>
        return
    endif
    let popup = s:all_popups[bufnr]
    let pos = win_screenpos('.')
    if popup.opened_at != [pos[1] + wincol() - 1, pos[0] + winline() - 1]
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
    if popup.bufnr == b
        return
    endif

    " This triggers s:on_close()
    call popup.close()

    if empty(s:all_popups)
        autocmd! plugin-git-messenger-buf-enter
    endif
endfunction

function! s:on_open(blame) dict abort
    if !has_key(a:blame.popup, 'bufnr')
        " For some reason, popup was already closed
        unlet! s:all_popups[a:blame.popup.opener_bufnr]
        return
    endif

    let opener_bufnr = a:blame.popup.opener_bufnr
    let s:all_popups[opener_bufnr] = a:blame.popup

    if g:git_messenger_close_on_cursor_moved
        augroup plugin-git-messenger-close
            autocmd CursorMoved,CursorMovedI,InsertEnter <buffer> call <SID>on_cursor_moved()
        augroup END
    endif

    augroup plugin-git-messenger-buf-enter
        execute 'autocmd BufEnter,WinEnter * call <SID>on_buf_enter(' . opener_bufnr . ')'
    augroup END
endfunction

function! s:on_close(popup) dict abort
    unlet! s:all_popups[a:popup.opener_bufnr]
endfunction

function! s:on_error(errmsg) abort
    echohl ErrorMsg
    " Avoid ^@
    for line in split(a:errmsg, '\r\=\n')
        echomsg line
    endfor
    echohl None
endfunction

" file: string
" line: number
" bufnr: number
" opts?: {}
function! gitmessenger#new(file, line, bufnr, ...) abort
    " When cursor is in popup window, close the window
    if gitmessenger#popup#close_current_popup()
        return
    endif

    " Just after opening a popup window, move cursor into the window
    if g:git_messenger_into_popup_after_show && has_key(s:all_popups, a:bufnr)
        let p = s:all_popups[a:bufnr]
        if has_key(p, 'bufnr')
            call p.into()
            return
        endif
    endif

    let opts = get(a:, 1, {})
    let opts.pos = getpos('.')
    " Close previous popup
    if has_key(s:all_popups, a:bufnr)
        call s:all_popups[a:bufnr].close()
    endif

    let blame = gitmessenger#blame#new(a:file, a:line, {
            \   'did_open': funcref('s:on_open', [], opts),
            \   'did_close': funcref('s:on_close', [], opts),
            \   'on_error': funcref('s:on_error'),
            \   'enter_popup': g:git_messenger_always_into_popup,
            \ })
    if blame isnot v:null
        call blame.start()
    endif
endfunction

function! s:popup_for(bufnr) abort
    if !has_key(s:all_popups, a:bufnr)
        return v:null
    endif

    let popup = s:all_popups[a:bufnr]
    if !has_key(popup, 'bufnr')
        " Here should be unreachable
        unlet! s:all_popups[a:bufnr]
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
