set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin indent on
syntax enable

set nomore

nnoremap q :qall!<cr>

silent edit test-cites.tex

if empty($INMAKE) | finish | endif

" Check validity of a single entry
let s:actions = v:lua.require('vimtex.context').inspect(9, 49)
call assert_equal('Hemingway1940', s:actions.selected)
call assert_equal(9, len(s:actions.entry))

" Check that we get the right key of another entry at a "difficult" spot
call assert_equal('JiM2020', v:lua.require('vimtex.context').inspect(11, 39).selected)

" Check that arxiv handler is available
call assert_equal('Open arXiv',
      \ v:lua.require('vimtex.context').inspect(14, 14).menu[3].name)
call assert_equal('Open arXiv',
      \ v:lua.require('vimtex.context').inspect(14, 39).menu[2].name)

call v:lua.require('vimtex.test').finished()
