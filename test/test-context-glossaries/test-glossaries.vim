set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin indent on
syntax enable

set nomore

nnoremap q :qall!<cr>

silent edit glossaries.tex

if empty($INMAKE) | finish | endif

let s:actions = v:lua.require('vimtex.context').inspect(15, 9)
call assert_equal('isbn', s:actions.selected)
call assert_equal(6, len(s:actions.entry))

call v:lua.require('vimtex.test').finished()
