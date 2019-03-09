if exists('b:current_syntax')
    finish
endif

syn match gitmessengerHeader '\_^ \%(History\|Commit\|Author\|Committer\):' display
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

let b:current_syntax = 'gitmessengerpopup'

