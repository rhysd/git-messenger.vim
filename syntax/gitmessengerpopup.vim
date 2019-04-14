if exists('b:current_syntax')
    finish
endif

syn match gitmessengerHeader '\_^ \%(History\|Commit\|Date\|Author\|Committer\):' display
syn match gitmessengerHash '\%(\<Commit: \)\@<=[[:xdigit:]]\+' display
syn match gitmessengerHistory '\%(\<History: \)\@<=#\d\+' display

" TODO: Choose nice background color by modifying current background color slightly
if &background ==# 'dark'
    hi def gitmessengerHeader      term=None guifg=#88b8f6 ctermfg=111
    hi def gitmessengerHash        term=None guifg=#f0eaaa ctermfg=229
    hi def gitmessengerHistory     term=None guifg=#fd8489 ctermfg=210
    hi def gitmessengerPopupNormal term=None guifg=#eeeeee guibg=#333333 ctermfg=255 ctermbg=234
    hi def gitmessengerEndOfBuffer term=None guifg=#333333 guibg=#333333 ctermfg=234 ctermbg=234
else
    hi def gitmessengerHeader      term=None guifg=#165bc0 ctermfg=26
    hi def gitmessengerHash        term=None guifg=#cb3749 ctermfg=167
    hi def gitmessengerHistory     term=None guifg=#6f40bc ctermfg=61
    hi def gitmessengerPopupNormal term=None guibg=#eeeeee guifg=#333333 ctermbg=255 ctermfg=234
    hi def gitmessengerEndOfBuffer term=None guibg=#333333 guifg=#333333 ctermbg=234 ctermfg=234
endif

" Diff included in popup
syn match diffRemoved "^ -.*" display
syn match diffAdded "^ +.*" display

syn match diffSubname "  @@..*"ms=s+3 contained display
syn match diffLine "^ @.*" contains=diffSubname display
syn match diffLine "^ \<\d\+\>.*" display
syn match diffLine "^ \*\*\*\*.*" display
syn match diffLine "^ ---$" display

" Some versions of diff have lines like "#c#" and "#d#" (where # is a number)
syn match diffLine "^ \d\+\(,\d\+\)\=[cda]\d\+\>.*" display

syn match diffFile "^ diff --git .*" display
syn match diffFile "^ +++ .*" display
syn match diffFile "^ ==== .*" display
syn match diffOldFile "^ \*\*\* .*" display
syn match diffNewFile "^ --- .*" display
syn match diffIndexLine "^ index \x\{7,}\.\.\x\{7,}.*" display

hi def link diffOldFile   diffFile
hi def link diffNewFile   diffFile
hi def link diffIndexLine PreProc
hi def link diffFile      Type
hi def link diffRemoved   Special
hi def link diffAdded     Identifier
hi def link diffLine      Statement
hi def link diffSubname   PreProc

let b:current_syntax = 'gitmessengerpopup'
