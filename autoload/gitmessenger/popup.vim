let s:popup = {}
let s:floating_window_available = has('nvim') && exists('*nvim_win_set_config')

function! s:popup__close() dict abort
    if !has_key(self, 'bufnr')
        " Already closed
        return
    endif

    let winnr = self.get_winnr()
    if winnr > 0
        " Without this 'noautocmd', the BufWipeout event will be triggered and
        " this function will be called again.
        noautocmd execute winnr . 'wincmd c'
    endif

    unlet self.bufnr
    unlet self.win_id

    if has_key(self.opts, 'did_close')
        call self.opts.did_close(self)
    endif
endfunction
let s:popup.close = funcref('s:popup__close')

function! s:popup__get_winnr() dict abort
    if !has_key(self, 'bufnr')
        return -1
    endif

    " Note: bufwinnr() is not available here because there may be multiple
    " windows which open the buffer. This situation happens when enter <C-w>v
    " in popup window. It opens a new normal window with the popup's buffer.
    return win_id2win(self.win_id)
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

function! s:popup__window_size() dict abort
    " Note: Unlike col('.'), wincol() considers length of sign column
    let origin = win_screenpos(bufwinnr(self.opener_bufnr))
    let abs_cursor_line = (origin[0] - 1) + self.opened_at[1] - line('w0')
    let abs_cursor_col = (origin[1] - 1) + wincol() - col('w0')

    let width = 0
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

    return [width, height]
endfunction
let s:popup.window_size = funcref('s:popup__window_size')

function! s:popup__floating_win_opts(width, height) dict abort
    let bottom_line = line('w0') + winheight(0) - 1
    if self.opened_at[1] + a:height <= bottom_line
        let vert = 'N'
        let row = 1
    else
        let vert = 'S'
        let row = 0
    endif

    if self.opened_at[2] + a:width <= &columns
        let hor = 'W'
        let col = 0
    else
        let hor = 'E'
        let col = 1
    endif

    return {
    \   'relative': 'cursor',
    \   'anchor': vert . hor,
    \   'row': row,
    \   'col': col,
    \   'width': a:width,
    \   'height': a:height,
    \ }
endfunction
let s:popup.floating_win_opts = funcref('s:popup__floating_win_opts')

function! s:popup__open() dict abort
    let self.opened_at = getpos('.')
    let self.opener_bufnr = bufnr('%')
    let self.type = s:floating_window_available ? 'floating' : 'preview'

    let [width, height] = self.window_size()

    " Open window
    if self.type ==# 'floating'
        let opts = self.floating_win_opts(width, height)
        let win_id = nvim_open_win(self.opener_bufnr, v:true, opts)
    else
        let mods = 'noswapfile'
        if g:git_messenger_preview_mods !=# ''
            let mods .= ' ' . g:git_messenger_preview_mods
        endif
        execute mods 'pedit!'
        wincmd P
        execute height . 'wincmd _'
        let win_id = win_getid()
    endif

    " Setup content
    enew!
    let popup_bufnr = bufnr('%')
    setlocal
    \ buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nonumber
    \ nocursorline wrap nonumber norelativenumber signcolumn=no nofoldenable
    \ nospell nolist nomodeline
    if has_key(self.opts, 'filetype')
        let &l:filetype = self.opts.filetype
    endif
    call setline(1, self.contents)
    setlocal nomodified nomodifiable

    " Setup highlights
    if has('nvim')
        setlocal winhighlight=Normal:gitmessengerPopupNormal,EndOfBuffer:gitmessengerEndOfBuffer
    endif

    if has_key(self.opts, 'mappings')
        for m in keys(self.opts.mappings)
            execute printf('nnoremap <buffer><silent>%s :<C-u>call b:__gitmessenger_popup.opts.mappings["%s"][0]()<CR>', m, m)
        endfor
        nnoremap <buffer>? :<C-u>call b:__gitmessenger_popup.echo_help()<CR>
    endif

    " Ensure to close popup
    let b:__gitmessenger_popup = self
    execute 'autocmd BufWipeout <buffer> call getbufvar(' . popup_bufnr . ', "__gitmessenger_popup").close()'

    if has_key(self.opts, 'enter') && !self.opts.enter
        wincmd p
    endif

    let self.bufnr = popup_bufnr
    let self.win_id = win_id
endfunction
let s:popup.open = funcref('s:popup__open')

function! s:popup__update() dict abort
    let prev_winnr = winnr()

    let popup_winnr = self.get_winnr()
    if popup_winnr == 0
        return
    endif
    let opener_winnr = bufwinnr(self.opener_bufnr)
    if opener_winnr < 0
        return
    endif

    if opener_winnr != prev_winnr
        execute opener_winnr . 'wincmd w'
    endif

    try
        let [width, height] = self.window_size()

        " Window must be configured in opener buffer since the window position
        " is relative to cursor
        if self.type ==# 'floating'
            let id = win_getid(popup_winnr)
            if id == 0
                return
            endif
            let opts = self.floating_win_opts(width, height)
            call nvim_win_set_config(id, opts)
        endif

        execute popup_winnr . 'wincmd w'

        if self.type ==# 'preview'
            execute height . 'wincmd _'
        endif

        setlocal modifiable
        silent %delete _
        call setline(1, self.contents)
        setlocal nomodified nomodifiable
    finally
        if winnr() != prev_winnr
            execute prev_winnr . 'wincmd w'
        endif
    endtry
endfunction
let s:popup.update = funcref('s:popup__update')

function! s:popup__echo_help() dict abort
    if has_key(self.opts, 'mappings')
        for [map, info] in items(self.opts.mappings)
            echo printf('%s: %s', map, info[1])
        endfor
    endif
    echo '?: Show this help'
endfunction
let s:popup.echo_help = funcref('s:popup__echo_help')

" contents: string[] // lines of contents
" opts: {
"   floating?: boolean;
"   bufnr?: number;
"   cursor?: [number, number]; // (line, col)
"   filetype?: string;
"   did_close?: (pupup: Popup) => void;
"   mappings?: {
"     [keyseq: string]: [() => void, string];
"   };
"   enter?: boolean
" }
function! gitmessenger#popup#new(contents, opts) abort
    let p = deepcopy(s:popup)
    let opts = { 'floating': v:true }
    call extend(opts, a:opts)
    let p.opts = opts
    let p.contents = a:contents
    return p
endfunction


" When current window is popup, close the window.
" Returns true when popup window was closed
function! gitmessenger#popup#close_current_popup() abort
    if !exists('b:__gitmessenger_popup')
        return 0
    endif
    call b:__gitmessenger_popup.close()
    " TODO?: Back to opened_at pos by setpos()
    return 1
endfunction
