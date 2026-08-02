set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on
syntax on

set selection=exclusive

setfiletype tex

call v:lua.require('vimtex.test').keys('f[did',
      \ 'text [delim] other text',
      \ 'text [] other text')

call v:lua.require('vimtex.test').keys('f[dad',
      \ 'text [delim] other text',
      \ 'text  other text')

call v:lua.require('vimtex.test').keys('f$di$',
      \ 'text $inline math$ other text',
      \ 'text $$ other text')

call v:lua.require('vimtex.test').keys('f$da$',
      \ 'text $inline math$ other text',
      \ 'text  other text')

call v:lua.require('vimtex.test').finished()
