let s:popup = {}
let s:floating_window_available = has('nvim') && exists('*nvim_win_set_config')

function! s:get_global_pos() abort
    let pos = win_screenpos('.')
    return [pos[0] + winline() - 1, pos[1] + wincol() - 1]
endfunction

function! s:popup__close() dict abort
    if !has_key(self, 'bufnr')
        " Already closed
        return
    endif

    if self.type ==# 'popup'
        call popup_close(self.win_id)
    else
        let winnr = self.get_winnr()
        if winnr > 0
            " Without this 'noautocmd', the BufWipeout event will be triggered and
            " this function will be called again.
            noautocmd execute winnr . 'wincmd c'
        endif
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

function! s:popup__set_buf_var(name, value) dict abort
    if has_key(self, 'bufnr')
        call setbufvar(self.bufnr, a:name, a:value)
    endif
endfunction
let s:popup.set_buf_var = funcref('s:popup__set_buf_var')

function! s:popup__scroll(map) dict abort
    if self.type ==# 'popup'
        return
    endif
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
    if self.type ==# 'popup'
        return
    endif
    let winnr = self.get_winnr()
    if winnr == 0
        return
    endif
    execute winnr . 'wincmd w'
endfunction
let s:popup.into = funcref('s:popup__into')

function! s:popup__window_size() dict abort
    let margin = g:git_messenger_popup_content_margins ? 1 : 0
    let has_max_width = type(g:git_messenger_max_popup_width) == v:t_number
    if has_max_width
        " ` - 1` for considering right margin
        let max_width = g:git_messenger_max_popup_width - margin
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
    let width += margin " right margin

    if type(g:git_messenger_max_popup_height) == v:t_number && height > g:git_messenger_max_popup_height
        let height = g:git_messenger_max_popup_height
    endif

    return [width, height]
endfunction
let s:popup.window_size = funcref('s:popup__window_size')

function! s:popup__floating_win_opts(width, height) dict abort
    let border = has_key(g:git_messenger_floating_win_opts, 'border')
                    \ && index(
                    \   ['single', 'double', 'rounded', 'solid'], g:git_messenger_floating_win_opts['border']
                    \ ) != -1 ? 2 : 0

    " &lines - 1 because it is not allowed to overlay a floating window on a status line.
    " Bottom line of a floating window must be less than line of command line. (#80)
    if self.opened_at[0] + a:height + border <= &lines - 1
        let vert = 'N'
        let row = self.opened_at[0]
    else
        let vert = 'S'
        let row = self.opened_at[0] - 1 - border
    endif

    if self.opened_at[1] + a:width + border <= &columns
        let hor = 'W'
        let col = self.opened_at[1] - 1
    else
        let hor = 'E'
        let col = self.opened_at[1] - border
    endif

    return extend({
        \   'relative': 'editor',
        \   'anchor': vert . hor,
        \   'row': row,
        \   'col': col,
        \   'width': a:width,
        \   'height': a:height,
        \   'style': 'minimal',
        \ },
        \ g:git_messenger_floating_win_opts)
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

function! s:popup__vimpopup_keymaps() dict abort
    " TODO: allow customisation via config var once happy with dict key names
    return {
        \   'scroll_down_1': ["\<c-e>", "\<c-n>", "\<Down>"],
        \   'scroll_up_1': ["\<c-y>", "\<c-p>", "\<Up>"],
        \   'scroll_down_page': ["\<c-f>", "\<PageDown>"],
        \   'scroll_up_page': ["\<c-b>", "\<PageUp>"],
        \   'scroll_down_half': ["\<c-d>"],
        \   'scroll_up_half': ["\<c-u>"],
        \ }
endfunction
let s:popup.vimpopup_keymaps = funcref('s:popup__vimpopup_keymaps')

function! s:popup__vimpopup_win_filter(win_id, key) dict abort
    " Note: default q handler assumes we are in the popup window, but in Vim we
    " cannot enter the popup window, so we override the handling here for now
    let keymaps = self.vimpopup_keymaps()
    if a:key ==# 'q'
        call self.close()
    elseif a:key ==# '?'
        call self.echo_help()
    elseif has_key(self.opts, 'mappings') && has_key(self.opts.mappings, a:key)
        call self.opts.mappings[a:key][0]()
    elseif index(keymaps['scroll_down_1'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-e>")
    elseif index(keymaps['scroll_up_1'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-y>")
    elseif index(keymaps['scroll_down_page'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-f>")
    elseif index(keymaps['scroll_up_page'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-b>")
    elseif index(keymaps['scroll_down_half'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-d>")
    elseif index(keymaps['scroll_up_half'], a:key) >= 0
        call win_execute(a:win_id, "normal! \<c-u>")
    elseif a:key ==? "\<ScrollWheelUp>"
        let pos = getmousepos()
        if pos.winid == a:win_id
            call win_execute(a:win_id, "normal! 3\<c-y>")
        else
            return 0
        endif
    elseif a:key ==? "\<ScrollWheelDown>"
        let pos = getmousepos()
        if pos.winid == a:win_id
            call win_execute(a:win_id, "normal! 3\<c-e>")
        else
            return 0
        endif
    else
        return 0
    endif
    return 1
endfunction
let s:popup.vimpopup_win_filter = funcref('s:popup__vimpopup_win_filter')

function! s:popup__vimpopup_win_opts(width, height) dict abort
    " Note: calculations here are not the same as for Neovim floating window as
    " Vim popup positioning relative to the editor window is slightly different,
    " but the end result is that the popup is in same position in Vim as Neovim
    if self.opened_at[0] + a:height <= &lines
        let vert = 'top'
        let row = self.opened_at[0] + 1
    else
        let vert = 'bot'
        let row = self.opened_at[0] - 1
    endif

    if self.opened_at[1] + a:width <= &columns
        let hor = 'left'
        let col = self.opened_at[1]
    else
        let hor = 'right'
        let col = self.opened_at[1]
    endif

    " Note: scrollbar disabled as seems buggy, even in Vim 9.1, scrollbar does
    " not reliably appear when content does not fit, which means scroll is not
    " always enabled when needed, so handle scroll in filter function instead.
    " This now works the same as Neovim, no scrollbar, but mouse scroll works.
    return extend({
        \   'line': row,
        \   'col': col,
        \   'pos': vert . hor,
        \   'filtermode': 'n',
        \   'filter': self.vimpopup_win_filter,
        \   'minwidth': a:width,
        \   'maxwidth': a:width,
        \   'minheight': a:height,
        \   'maxheight': a:height,
        \   'scrollbar': v:false,
        \   'highlight': 'gitmessengerPopupNormal'
        \ },
        \ g:git_messenger_vimpopup_win_opts)
endfunction
let s:popup.vimpopup_win_opts = funcref('s:popup__vimpopup_win_opts')

function! s:popup__vimpopup_win_callback(win_id, result) dict abort
    " Hacky custom cleanup for vimpopup, necessary as buffer never entered
    silent! unlet b:__gitmessenger_popup
    autocmd! plugin-git-messenger-close * <buffer>
    autocmd! plugin-git-messenger-buf-enter
endfunction
let s:popup.vimpopup_win_callback = funcref('s:popup__vimpopup_win_callback')

function! s:popup__open() dict abort
    let self.opened_at = s:get_global_pos()
    let self.opener_bufnr = bufnr('%')
    let self.opener_winid = win_getid()

    if g:git_messenger_vimpopup_enabled && has('popupwin')
        let self.type = 'popup'
        let [width, height] = self.window_size()
        let win_id = popup_create('', self.vimpopup_win_opts(width, height))
        " Note: all local options are automatically set for new popup buffers
        " in Vim so we only need to override a few, see :help popup-buffer
        call win_execute(win_id, 'setlocal nomodified nofoldenable nomodeline conceallevel=2')
        call popup_settext(win_id, self.contents)
        call win_execute(win_id, 'setlocal nomodified nomodifiable')
        if has_key(self.opts, 'filetype')
            " Note: setbufvar() seems necessary to trigger Filetype autocmds
            call setbufvar(winbufnr(win_id), '&filetype', self.opts.filetype)
        endif
        " Allow multiple invocations of :GitMessenger command to toggle popup
        " See gitmessenger#popup#close_current_popup() and gitmessenger#new()
        let b:__gitmessenger_popup = self " local to opener, removed by callback
        call popup_setoptions(win_id, { 'callback': self.vimpopup_win_callback })
        let self.bufnr = winbufnr(win_id)
        let self.win_id = win_id
        return
    endif

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
    " Note: Set conceallevel for hiding word diff markers
    setlocal
    \ buftype=nofile bufhidden=wipe nomodified nobuflisted noswapfile nonumber
    \ nocursorline wrap nonumber norelativenumber signcolumn=no nofoldenable
    \ nospell nolist nomodeline conceallevel=2
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
        if self.type !=# 'floating'
            " Opening a preview window may move global position of the cursor.
            " `opened_at` is used for checking if the popup window should be
            " closed on `CursorMoved` event. If the position is not updated
            " here, the event wrongly will refer the position before opening
            " the preview window.
            let self.opened_at = s:get_global_pos()
        endif
    endif

    let self.bufnr = popup_bufnr
    let self.win_id = win_id
endfunction
let s:popup.open = funcref('s:popup__open')

function! s:popup__update() dict abort

    if self.type ==# 'popup'
        let [width, height] = self.window_size()
        let win_id = self.win_id
        call popup_setoptions(self.win_id, self.vimpopup_win_opts(width, height))
        call win_execute(win_id, 'setlocal modifiable')
        call popup_settext(win_id, self.contents)
        call win_execute(win_id, 'setlocal nomodified nomodifiable')
        return
    endif

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

" Returns if the cursor moved since this popup window had opened
function! s:popup__cursor_moved() dict abort
    return s:get_global_pos() != self.opened_at
endfunction
let s:popup.cursor_moved = funcref('s:popup__cursor_moved')

function! s:popup__echo_help() dict abort
    if has_key(self.opts, 'mappings')
        let maps = keys(self.opts.mappings)
        call sort(maps, 'i')
        let maps += ['?']

        " When using Vim popup only one echo command output is shown in cmdline
        if self.type ==# 'popup'
            let lines = map(maps, {_, map ->
                \ map . ' : ' . ( map ==# '?' ? 'Show this help' : self.opts.mappings[map][1] )
                \ })
            echo join(lines, "\n")
            return
        endif

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
