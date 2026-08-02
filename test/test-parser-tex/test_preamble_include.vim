set nocompatible
let &rtp = '../..,' . &rtp

nnoremap q :qall!<cr>

let s:lines = v:lua.require('vimtex.parser').preamble('test_preamble_include.tex')

call assert_equal(
      \ readfile('test_preamble_include.ref'),
      \ s:lines)

call v:lua.require('vimtex.test').finished()
