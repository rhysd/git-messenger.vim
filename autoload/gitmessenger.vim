let s:git = {}

function! s:on_output(job, data, event) dict abort
    if a:data == ['']
        return
    endif
    let self[a:event][-1] .= a:data[0]
    call extend(self[a:event], a:data[1:])
endfunction

function! s:on_exit(job, code, event) dict abort
    let self.exit_status = a:code
    call self.on_exit(self)
endfunction

function! s:git__spawn(args, cwd, on_exit) dict abort
    let cmdline = [self.cmd] + a:args
    let self.stdout = ['']
    let self.stderr = ['']
    let job_id = jobstart(cmdline, {
                \   'cwd': a:cwd,
                \   'on_stdout' : funcref('s:on_output', [], self),
                \   'on_exit' : funcref('s:on_exit', [], self),
                \ })
    if job_id == 0
        throw 'gitmessenger: Invalid arguments: ' . string(a:args)
    elseif job_id == -1
        throw 'gitmessenger: Command does not exist: ' . self.cmd
    endif
    let self.job_id = job_id
    let self.on_exit = a:on_exit
    let self.args = a:args
    return job_id
endfunction
let s:git.spawn = funcref('s:git__spawn')

function! s:git_command(cmd) abort
    let g = deepcopy(s:git)
    let g.cmd = a:cmd
    return g
endfunction



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
function! s:new_popup(contents, opts) abort
    let p = deepcopy(s:popup)
    let opts = { 'floating': v:true }
    call extend(opts, a:opts)
    let p.opts = opts
    let p.contents = a:contents
    return p
endfunction



let s:blame = {}

function! s:blame__after_cmd(git) dict abort
    let self.failed = a:git.exit_status != 0

    if self.failed
        throw printf(
            \   '`%s %s` exited with non-zero status %d: %s',
            \   a:git.cmd,
            \   join(a:git.args, ' '),
            \   a:git.exit_status,
            \   join(a:git.stderr, ' ')
            \ )
    endif

    " Parse `blame --porcelain` output
    let stdout = a:git.stdout
    let hash = matchstr(stdout[0], '^\S\+')
    let author = matchstr(stdout[1], '^author \zs.\+')
    let author_email = matchstr(stdout[2], '^author-email \zs\S\+')
    let lines = [
        \   '',
        \   ' Commit: ' . hash,
        \   ' Author: ' . author . ' ' . author_email,
        \ ]
    let committer = matchstr(stdout[5], '^committer \zs.\+')
    if author !=# committer
        let committer_email = matchstr(stdout[6], '^committer-mail \zs\S\+')
        let lines += [' Committer: ' . committer . ' ' . committer_email]
    endif
    let summary = matchstr(stdout[9], '^summary \zs.*')
    let lines += ['', ' ' . summary, '']

    let opts = {}
    if has_key(self.opts, 'did_close')
        let opts.did_close = self.opts.did_close
    endif

    let self.popup = s:new_popup(lines, opts)
    call self.popup.open()

    if has_key(self.opts, 'did_open')
        call self.opts.did_open(self)
    endif
endfunction

function! s:blame__start() dict abort
    let args = ['--no-pager', 'blame', self.file, '-L', self.line . ',+1', '--porcelain']
    let cwd = fnamemodify(self.file, ':p:h')
    " TODO: Make git command customizable
    let git = s:git_command('git')
    call git.spawn(args, cwd, funcref('s:blame__after_cmd', [], self))
endfunction
let s:blame.start = funcref('s:blame__start')

" file: string
" line: number
" opts: {
"   did_open: (b: Blame) => void
"   did_close: (p: Popup) => void
" }
function! s:new_blame(file, line, opts) abort
    let b = deepcopy(s:blame)
    let b.line = a:line
    let b.file = a:file
    let b.opts = a:opts
    return b
endfunction



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

    let blame = s:new_blame(a:file, a:line, {
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
