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
    if !has_key(self, 'bufnr')
        return -1
    endif
    return bufwinnr(self.bufnr)
endfunction
let s:popup.get_winnr = funcref('s:popup__get_winnr')

function! s:popup__scroll(map) dict abort
    let winnr = self.get_winnr()
    if winnr < 0
        return
    endif
    execute winnr . 'wincmd w'
    sandbox let input = eval('"\<'.a:map.'>"')
    execute "normal!" input
    wincmd p
endfunction
let s:popup.scroll = funcref('s:popup__scroll')

function! s:popup__into() dict abort
    let winnr = self.get_winnr()
    if winnr < 0
        return
    endif
    execute winnr . 'wincmd w'
endfunction
let s:popup.into = funcref('s:popup__into')

function! s:popup__open() dict abort
    " Note: Unlike col('.'), wincol() considers length of sign column
    let opener_pos = getpos('.')
    let opener_bufnr = bufnr('%')
    let origin = win_screenpos(bufwinnr(opener_bufnr))
    let abs_cursor_line = (origin[0] - 1) + opener_pos[1] - line('w0')
    let abs_cursor_col = (origin[1] - 1) + wincol() - col('w0')

    let width = has_key(self.opts, 'width') ? self.opts.width : 60
    let max_width = 100
    let height = 0
    for line in self.contents
        let lw = strdisplaywidth(line)
        if lw > width
            if lw > max_width
                let height += lw / max_width + 1
                let width = max_width
                continue
            endif
            let width = lw
        endif
        let height += 1
    endfor
    let width += 1 " right margin

    " Open window
    if s:floating_window_available
        if opener_pos[1] + height <= line('w$')
            let vert = 'N'
            let row = 1
        else
            let vert = 'S'
            let row = 0
        endif

        if opener_pos[2] + width <= &columns
            let hor = 'W'
            let col = 0
        else
            let hor = 'E'
            let col = 1
        endif

        call nvim_open_win(opener_bufnr, v:true, width, height, {
            \   'relative': 'cursor',
            \   'anchor': vert . hor,
            \   'row': row,
            \   'col': col,
            \ })
        let self.type = 'floating'
    else
        pedit!
        wincmd P
        execute height . 'wincmd _'
        let self.type = 'preview'
    endif

    " Setup content
    enew!
    setlocal buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nonumber nocursorline wrap
    if has_key(self.opts, 'filetype')
        let &l:filetype = self.opts.filetype
    endif
    let popup_bufnr = bufnr('%')
    call setline(1, self.contents)
    setlocal nomodified nomodifiable

    " Setup highlights
    if has('nvim')
        setlocal winhighlight=Normal:gitmessengerPopupNormal,EndOfBuffer:gitmessengerEndOfBuffer
    endif

    " Ensure to close popup
    let b:__gitmessenger_popup = self
    execute 'autocmd BufWipeout <buffer> call getbufvar(' . popup_bufnr . ', "__gitmessenger_popup").close()'

    wincmd p

    let self.bufnr = popup_bufnr
    let self.opener_bufnr = opener_bufnr
    let self.opened_at = opener_pos
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
