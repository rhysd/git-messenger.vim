let s:popup = {}
let s:floating_window_available = has('nvim') && exists('*nvim_open_win')

function! s:popup__close() dict abort
    if !has_key(self, 'bufnr')
        " Already closed
        return
    endif
    let winnr = self.get_winnr()
    if winnr >= 0
        " Without this 'autocmd', the BufWipeout event will be triggered and
        " this function will be called again.
        noautocmd execute winnr . 'wincmd c'
    endif
    unlet self.bufnr
    if has_key(self, 'did_close')
        call self.did_close(self)
    endif
endfunction
let s:popup.close = funcref('s:popup__close')

function! s:popup__get_winnr() dict abort
    return bufwinnr(self.bufnr)
endfunction
let s:popup.get_winnr = funcref('s:popup__get_winnr')

function! s:popup__open() dict abort
    " Note: Unlike col('.'), wincol() considers length of sign column
    let first_pos = getpos('.')
    let cursor = has_key(self.opts, 'cursor') ? self.opts.cursor : [first_pos[1], wincol()]
    let opener_bufnr = has_key(self.opts, 'bufnr') ? self.opts.bufnr : bufnr('%')
    let origin = win_screenpos(bufwinnr(opener_bufnr))
    let win_top_line = has_key(self.opts, 'win_top_line') ? self.opts.win_top_line : line('w0')
    let win_top_col = has_key(self.opts, 'win_top_col') ? self.opts.win_top_col : col('w0')
    let abs_cursor_line = (origin[0] - 1) + (win_top_line - 1) + cursor[0]
    let abs_cursor_col = (origin[1] - 1) + (win_top_col - 1) + cursor[1]
    let total_lines = &lines
    let total_cols = &columns

    let shown_above = abs_cursor_line > total_lines / 2
    let max_height = has_key(self.opts, 'height') ? self.opts.height : 30

    if shown_above
        let height = abs_cursor_line
        if height > max_height
            let height = max_height
        endif
        let top = abs_cursor_line - height - 1
    else
        let height = total_lines - abs_cursor_line
        if height > max_height
            let height = max_height
        end
        let top = abs_cursor_line
    endif
    if top < 0
        let top = 0
    endif

    let shown_left = abs_cursor_col > total_cols / 2
    let max_width = has_key(self.opts, 'width') ? self.opts.width : 60

    if shown_left
        let width = abs_cursor_col
        if width > max_width
            let width = max_width
        endif
        let left = abs_cursor_col - width + 1
    else
        let width = total_cols - abs_cursor_col
        if width > max_width
            let width = max_width
        end
        let left = abs_cursor_col
    endif
    if left < 0
        let left = 0
    endif

    " Consider line wrapping
    let num_lines = 0
    for line in self.contents
        let num_lines += strdisplaywidth(line) / width + 1
    endfor
    if num_lines < height
        if shown_above
            let top += height - num_lines
        endif
        let height = num_lines
    endif

    if !s:floating_window_available
        " TODO
        throw 'gitmessenger: TODO: Fall back into preview window'
    else
        call nvim_open_win(
            \   opener_bufnr,
            \   v:true,
            \   width,
            \   height,
            \   {
            \       'relative': 'editor',
            \       'row': top,
            \       'col': left,
            \   }
            \ )
    endif

    enew!
    setlocal buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nonumber nocursorline wrap
    if has_key(self.opts, 'filetype')
        let &l:filetype = self.opts.filetype
    endif
    let popup_bufnr = bufnr('%')
    call setline(1, self.contents)
    setlocal nomodified nomodifiable

    " TODO: Add autocmd to clear self.pupup_bufnr when this window is closed

    " TODO: Choose nice background color by modifying current background color slightly
    if &background ==# 'dark'
        hi GitMessengerPopupNormal term=None guifg=#eeeeee guibg=#333333 ctermfg=255 ctermbg=234
        hi GitMessengerEndOfBuffer term=None guifg=#333333 guibg=#333333 ctermfg=234 ctermbg=234
    else
        hi GitMessengerPopupNormal term=None guibg=#eeeeee guifg=#333333 ctermbg=255 ctermfg=234
        hi GitMessengerEndOfBuffer term=None guibg=#333333 guifg=#333333 ctermbg=234 ctermfg=234
    endif
    setlocal winhighlight=Normal:GitMessengerPopupNormal,EndOfBuffer:GitMessengerEndOfBuffer

    " Ensure to close popup
    let b:__gitmessenger_popup = self
    execute 'autocmd BufWipeout <buffer> call getbufvar(' . popup_bufnr . ', "__gitmessenger_popup").close()'

    wincmd p

    let self.bufnr = popup_bufnr
    let self.opener_bufnr = opener_bufnr
    let self.opened_at = first_pos
endfunction
let s:popup.open = funcref('s:popup__open')

" contents: string[] // lines of contents
" opts: {
"   floating?: boolean;
"   bufnr?: number;
"   cursor?: [number, number]; // (line, col)
"   filetype?: string;
"   did_close?: (pupup: Popup) => void;
" }
function! gitmessenger#popup#new(contents, opts) abort
    let p = deepcopy(s:popup)
    let opts = { 'floating': v:true }
    call extend(opts, a:opts)
    let p.opts = opts
    let p.contents = a:contents
    return p
endfunction
