set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore

nnoremap q :qall!<cr>

silent edit main.tex

if empty($INMAKE) | finish | endif

let s:toc = v:lua.require('vimtex.toc').get_entries(v:false)

let b:vimtex.toc.number_width = 4
let b:vimtex.toc.number_format = '%-4s'
call v:lua.require('vimtex.toc').print_entry(s:toc[14], b:vimtex.toc)

call assert_equal('L1 3.1 $L^p$ spaces', getline('$'))

call v:lua.require('vimtex.test').finished()
