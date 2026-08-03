set nocompatible
let &rtp = '../..,' . &rtp

nnoremap q :qall!<cr>

let s:lines = v:lua.require('vimtex.parser').preamble('test_preamble_include.tex')

call assert_equal(
      \ readfile('test_preamble_include.ref'),
      \ s:lines)

" Cached reads must still return an independent list because syntax setup
" filters and maps its result in place.
let s:cached = v:lua.require('vimtex.parser').preamble(
      \ 'test_preamble_include.tex', {'cached': v:true})
let s:cached[0] = 'mutated'
call assert_equal(
      \ readfile('test_preamble_include.ref'),
      \ v:lua.require('vimtex.parser').preamble(
      \   'test_preamble_include.tex', {'cached': v:true}))

call v:lua.require('vimtex.test').finished()
