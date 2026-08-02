set nocompatible
set runtimepath^=../../../
filetype plugin indent on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '../.'

silent edit test.tex

call assert_equal(
      \ 'test-kpsewhich-local-b/local.bib',
      \ v:lua.require('vimtex.paths').relative(
      \   v:lua.require('vimtex.kpsewhich').find('local.bib'),
      \ expand('%:p:h:h')))

call v:lua.require('vimtex.test').finished()
