set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

silent edit minimal.tex

if empty($INMAKE) | finish | endif

call assert_equal('50', v:lua.require('vimtex.misc').wordcount())

call assert_equal('25', v:lua.require('vimtex.misc').wordcount({'range': [4, 5]}))

call v:lua.require('vimtex.test').finished()
