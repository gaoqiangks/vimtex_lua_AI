set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>
silent edit test.tex

if empty($INMAKE) | finish | endif

call cursor([3, 15])
call assert_equal({
      \ 'candidates': ['amsmath', 'mathtools'],
      \ 'type': 'usepackage',
      \ 'selected': 'amsmath'
      \}, v:lua.require('vimtex.doc').get_context())

call cursor([3, 25])
call assert_equal({
      \ 'candidates': ['amsmath', 'mathtools'],
      \ 'type': 'usepackage',
      \ 'selected': 'mathtools'
      \}, v:lua.require('vimtex.doc').get_context())

call v:lua.require('vimtex.test').finished()
