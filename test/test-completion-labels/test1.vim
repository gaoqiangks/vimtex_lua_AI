set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'
let g:vimtex_cache_persistent = 0
let g:vimtex_complete_ref = {
      \ 'custom_patterns': ['\\sref\*\{-}{[^}]*$'],
      \}

silent edit test1.tex

if empty($INMAKE) | finish | endif

call assert_equal('vimtex#complete#omnifunc', &l:omnifunc)

let s:candidates = v:lua.require('vimtex.test').completion('\ref{', '')
call assert_equal(24, len(s:candidates))

let s:candidates = v:lua.require('vimtex.test').completion('\eqref{', '')
call assert_equal(16, len(s:candidates))

let s:candidates = v:lua.require('vimtex.test').completion('\sref{', '')
call assert_equal(24, len(s:candidates))

call v:lua.require('vimtex.test').finished()
