set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set fillchars=fold:\ 
set number
set foldcolumn=4

nnoremap q :qall!<cr>

call v:lua.require('vimtex.log').set_silent()

let g:vimtex_fold_enabled = 1

silent edit test-sections.tex

if empty($INMAKE) | finish | endif

call assert_equal(2, foldlevel(10))

call v:lua.require('vimtex.test').finished()
