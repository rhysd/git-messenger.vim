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
        return 0
    endif

    " Note: bufwinnr() is not available here because there may be multiple
    " windows which open the buffer. This situation happens when enter <C-w>v
    " in popup window. It opens a new normal window with the popup's buffer.
    return win_id2win(self.win_id)
endfunction
let s:popup.get_winnr = funcref('s:popup__get_winnr')

function! s:popup__scroll(map) dict abort
    let winnr = self.get_winnr()
    if winnr == 0
        return
    endif
    execute winnr . 'wincmd w'
    sandbox let input = eval('"\<'.a:map.'>"')
    execute 'normal!' input
    wincmd p
endfunction
let s:popup.scroll = funcref('s:popup__scroll')

function! s:popup__into() dict abort
    let winnr = self.get_winnr()
    if winnr == 0
        return
    endif
    execute winnr . 'wincmd w'
endfunction
let s:popup.into = funcref('s:popup__into')

function! s:popup__window_size() dict abort
    let has_max_width = type(g:git_messenger_max_popup_width) == v:t_number
    if has_max_width
        " ` - 1` for considering right margin
        let max_width = g:git_messenger_max_popup_width - 1
    endif

    let width = 0
    let height = 0
    for line in self.contents
        let lw = strdisplaywidth(line)
        if lw > width
            if has_max_width && lw > max_width
                let height += lw / max_width + 1
                let width = max_width
                continue
            endif
            let width = lw
        endif
        let height += 1
    endfor
    let width += 1 " right margin

    if type(g:git_messenger_max_popup_height) == v:t_number && height > g:git_messenger_max_popup_height
        let height = g:git_messenger_max_popup_height
    endif

    return [width, height]
endfunction
let s:popup.window_size = funcref('s:popup__window_size')

function! s:popup__floating_win_opts(width, height) dict abort
    if self.opened_at[0] + a:height <= &lines
        let vert = 'N'
        let row = self.opened_at[0]
    else
        let vert = 'S'
        let row = self.opened_at[0] - 1
    endif

    if self.opened_at[1] + a:width <= &columns
        let hor = 'W'
        let col = self.opened_at[1] - 1
    else
        let hor = 'E'
        let col = self.opened_at[1]
    endif

    return {
    \   'relative': 'editor',
    \   'anchor': vert . hor,
    \   'row': row,
    \   'col': col,
    \   'width': a:width,
    \   'height': a:height,
    \   'style': 'minimal',
    \ }
endfunction
let s:popup.floating_win_opts = funcref('s:popup__floating_win_opts')

function! s:popup__get_opener_winnr() dict abort
    let winnr = win_id2win(self.opener_winid)
    if winnr != 0
        return winnr
    endif
    let winnr = bufwinnr(self.opener_bufnr)
    if winnr > 0
        return winnr
    endif
    return 0
endfunction
let s:popup.get_opener_winnr = funcref('s:popup__get_opener_winnr')

function! s:popup__open() dict abort
    let pos = win_screenpos('.')
    let self.opened_at = [pos[0] + winline() - 1, pos[1] + wincol() - 1]
    let self.opener_bufnr = bufnr('%')
    let self.opener_winid = win_getid()
    let self.type = s:floating_window_available ? 'floating' : 'preview'

    let [width, height] = self.window_size()

    " Open window
    if self.type ==# 'floating'
        let opts = self.floating_win_opts(width, height)
        let win_id = nvim_open_win(self.opener_bufnr, v:true, opts)
    else
        let curr_pos = getpos('.')
        let mods = 'noswapfile'
        if g:git_messenger_preview_mods !=# ''
            let mods .= ' ' . g:git_messenger_preview_mods
        endif

        " :pedit! is not available since it refreshes the file buffer (#39)
        execute mods 'new'
        set previewwindow

        call setpos('.', curr_pos)
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
    call setline(1, self.contents)
    setlocal nomodified nomodifiable

    " Setup highlights
    if has('nvim')
        setlocal winhighlight=Normal:gitmessengerPopupNormal
    endif

    if has_key(self.opts, 'mappings')
        for m in keys(self.opts.mappings)
            execute printf('nnoremap <buffer><silent><nowait>%s :<C-u>call b:__gitmessenger_popup.opts.mappings["%s"][0]()<CR>', m, m)
        endfor
        nnoremap <buffer><silent><nowait>? :<C-u>call b:__gitmessenger_popup.echo_help()<CR>
    endif

    if has_key(self.opts, 'filetype')
        let &l:filetype = self.opts.filetype
    endif

    " Ensure to close popup
    let b:__gitmessenger_popup = self
    execute 'autocmd BufWipeout,BufLeave <buffer> call getbufvar(' . popup_bufnr . ', "__gitmessenger_popup").close()'

    if has_key(self.opts, 'enter') && !self.opts.enter
        noautocmd wincmd p
    endif

    let self.bufnr = popup_bufnr
    let self.win_id = win_id
endfunction
let s:popup.open = funcref('s:popup__open')

function! s:popup__update() dict abort
    " Note: `:noautocmd` to prevent BufLeave autocmd event (#13)
    " It should be ok because the cursor position is finally back to the first
    " position.

    let prev_winnr = winnr()

    let popup_winnr = self.get_winnr()
    if popup_winnr == 0
        return
    endif
    let opener_winnr = self.get_opener_winnr()
    if opener_winnr == 0
        return
    endif

    if opener_winnr != prev_winnr
        noautocmd execute opener_winnr . 'wincmd w'
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

        noautocmd execute popup_winnr . 'wincmd w'

        if self.type ==# 'preview'
            execute height . 'wincmd _'
        endif

        setlocal modifiable
        silent %delete _
        call setline(1, self.contents)
        setlocal nomodified nomodifiable
    finally
        if winnr() != prev_winnr
            noautocmd execute prev_winnr . 'wincmd w'
        endif
    endtry
endfunction
let s:popup.update = funcref('s:popup__update')

function! s:popup__echo_help() dict abort
    if has_key(self.opts, 'mappings')
        let maps = keys(self.opts.mappings)
        call sort(maps, 'i')
        let maps += ['?']

        for map in maps
            if map ==# '?'
                let desc = 'Show this help'
            else
                let desc = self.opts.mappings[map][1]
            endif
            echohl Identifier | echo ' ' . map
            echohl Comment    | echon ' : '
            echohl None       | echon desc
        endfor
    endif
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
