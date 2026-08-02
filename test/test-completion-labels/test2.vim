set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'
let g:vimtex_cache_persistent = 0

silent edit test2.tex

if empty($INMAKE) | finish | endif

let s:candidates = v:lua.require('vimtex.test').completion('\ref{', '')
call assert_equal(len(s:candidates), 2)

let s:candidates = v:lua.require('vimtex.test').completion('\ref{', '1-')
call assert_equal(len(s:candidates), 1)

call v:lua.require('vimtex.test').finished()
