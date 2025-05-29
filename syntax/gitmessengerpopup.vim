if exists('b:current_syntax')
    finish
endif

syn match gitmessengerHeader '^ \=\%(History\|Commit\|\%(Author \|Committer \)\=Date\|Author\|Committer\):' display
syn match gitmessengerHash '\%(^ \=Commit: \+\)\@<=[[:xdigit:]]\+' display
syn match gitmessengerHistory '\%(^ \=History: \+\)\@<=#\d\+' display
syn match gitmessengerEmail '\%(^ \=\%(Author\|Committer\): \+.*\)\@<=<.\+>' display

" Diff included in popup
" There are two types of diff format; 'none' 'current', 'all', 'current.word', 'all.word'.
" 'current.word' and 'all.word' are for word diff. And 'current' and 'all' are " for unified diff.
" Define different highlights for unified diffs and word diffs.
" b:__gitmessenger_diff is set by Blame.render() in blame.vim.
if get(b:, '__gitmessenger_diff', '') =~# '\.word$'
    if has('conceal') && get(g:, 'git_messenger_conceal_word_diff_marker', v:true)
        syn region diffWordsRemoved matchgroup=Conceal start=/\[-/ end=/-]/ concealends oneline
        syn region diffWordsAdded matchgroup=Conceal start=/{+/ end=/+}/ concealends oneline
    else
        syn region diffWordsRemoved start=/\[-/ end=/-]/ oneline
        syn region diffWordsAdded start=/{+/ end=/+}/ oneline
    endif
else
    syn match diffRemoved "^ \=-.*" display
    syn match diffAdded "^ \=+.*" display
endif

syn match diffFile "^ \=diff --git .*" display
syn match diffOldFile "^ \=--- a\>.*" display
syn match diffNewFile "^ \=+++ b\>.*" display
syn match diffIndexLine "^ \=index \x\{7,}\.\.\x\{7,}.*" display
syn match diffLine "^ \=@@ .*" display

hi def link gitmessengerHeader      Identifier
hi def link gitmessengerHash        Comment
hi def link gitmessengerHistory     Constant
hi def link gitmessengerEmail       gitmessengerPopupNormal
if has('nvim')
    hi def link gitmessengerPopupNormal NormalFloat
else
    hi def link gitmessengerPopupNormal Pmenu
endif

hi def link diffOldFile      diffFile
hi def link diffNewFile      diffFile
hi def link diffIndexLine    PreProc
hi def link diffFile         Type
hi def link diffRemoved      Special
hi def link diffAdded        Identifier
hi def link diffWordsRemoved diffRemoved
hi def link diffWordsAdded   diffAdded
hi def link diffLine         Statement

let b:current_syntax = 'gitmessengerpopup'
