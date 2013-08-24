let s:save_cpo = &cpo
set cpo&vim

function! s:has_vimproc()
  if !exists('s:exists_vimproc')
    try
      call vimproc#version()
      let s:exists_vimproc = 1
    catch
      let s:exists_vimproc = 0
    endtry
  endif
  return s:exists_vimproc
endfunction

function! s:system(str, ...)
  let command = a:str
  let input = a:0 >= 1 ? a:1 : ''

  if a:0 == 0
    let output = s:has_vimproc() ?
          \ vimproc#system(command) : system(command)
  elseif a:0 == 1
    let output = s:has_vimproc() ?
          \ vimproc#system(command, input) : system(command, input)
  else
    " ignores 3rd argument unless you have vimproc.
    let output = s:has_vimproc() ?
          \ vimproc#system(command, input, a:2) : system(command, input)
  endif

  return output
endfunction

function! gitmessenger#commit_summary(file, line)
    let git_blame = split(s:system('git --no-pager blame '.a:file.' -L '.a:line.',+1 --porcelain'), "\n")
    let l:shell_error = s:has_vimproc() ? vimproc#get_last_status() : v:shell_error
    if l:shell_error && git_blame[0] =~# '^fatal: Not a git repository'
        return 'Error: Not a git repository'
    endif

    let commit_hash = matchstr( git_blame[0], '^\^*\zs\S\+' )
    if commit_hash =~# '^0\+$'
        " not committed yet
        return ''
    endif

    let summary = ''
    for line in git_blame
        if line =~# '^summary '
            let summary = matchstr(line, '^summary \zs.\+$')
            break
        endif
    endfor

    return '['.commit_hash[0:8].'] '.summary
endfunction

function! gitmessenger#echo()
    let file = expand('%')
    let line = line('.')
    echo gitmessenger#commit_summary(file, line)
endfunction

function! gitmessenger#balloon_expr()
    return gitmessenger#commit_message(bufname(v:beval_bufnr), v:beval_lnum)
endfunction


" experimental {{{
function! gitmessenger#commit_hash(file, line)
    let raw_result = s:system('git --no-pager blame -s '.a:file.' -L '.a:line.',+1')
    let commit_hash = matchstr(raw_result, '^\^*\zs\S\+')
    return commit_hash
endfunction

function! gitmessenger#commit_message(file, line)
    let commit_hash = gitmessenger#commit_hash(a:file, a:line)
    return join(split(s:system('git --no-pager cat-file commit '.commit_hash), "\n")[5:], "\n")
endfunction

function! gitmessenger#reset_cache()
    let s:message_cache = {}
    let s:line_cache = {}
endfunction
call gitmessenger#reset_cache()

function! s:parse_porcelain(lines)
    let i = 0
    let len = len(a:lines)
    while i < len
        if a:lines[i] =~# '^[0-9a-f]\+ \d\+ \d\+' && a:lines[i] !~# '^0\+ '
            let match = matchlist(a:lines[i], '\(^[0-9a-f]\+\) \d\+ \(\d\+\)')
            let commit_hash = match[1]
            let linum = match[2]
            let s:line_cache[linum] = commit_hash
            if ! has_key(s:message_cache, commit_hash)
                while a:lines[i] !~# '^summary '
                    let i = i + 1
                endwhile
                let s:message_cache[commit_hash] = matchstr(a:lines[i], '^summary \zs.\+$')
            endif
        endif
        let i = i + 1
    endwhile
endfunction

function! gitmessenger#blame_porcelain(file)
    let git_blame = split(s:system('git --no-pager blame '.a:file.' --porcelain'), "\n")
    let l:shell_error = s:has_vimproc() ? vimproc#get_last_status() : v:shell_error
    if l:shell_error && git_blame[0] =~# '^fatal: Not a git repository'
        " FIXME
        let s:line_cache[0] = 'dummy'
        return
    endif
    call s:parse_porcelain(git_blame)
endfunction

function! gitmessenger#echo2()
    if empty(s:message_cache) && empty(s:line_cache)
        call gitmessenger#blame_porcelain(expand('%'))
    endif
    let l = line('.')
    if has_key(s:line_cache, l)
        echo '['.s:line_cache[l][0:8].'] '.s:message_cache[s:line_cache[l]]
    else
        echo ''
    endif
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
