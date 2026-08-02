set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'
let g:vimtex_cache_persistent = 0
if !empty($BACKEND)
  let g:vimtex_parser_bib_backend = $BACKEND
endif

silent edit test_backend.tex

if empty($INMAKE) | finish | endif

if g:vimtex_parser_bib_backend ==# 'lua' && !has('nvim')
  call v:lua.require('vimtex.test').finished()
endif

" Simplify test on basic systems
if empty(v:lua.require('vimtex.kpsewhich').find('biblatex-examples.bib'))
  let s:candidates = v:lua.require('vimtex.test').completion('\cite{', '')
  call assert_true(len(s:candidates) >= 1)
  call v:lua.require('vimtex.test').finished()
  quit!
endif

let s:candidates = v:lua.require('vimtex.test').completion('\cite{', '')
call assert_equal(94, len(s:candidates))

let s:candidates = v:lua.require('vimtex.test').completion('\citet{', '.*ocal')
call assert_equal(2, len(s:candidates))

let s:candidates = v:lua.require('vimtex.test').completion(
      \ '\parencite[see][5--10]{', 'Arist.*1929')
call assert_equal(1, len(s:candidates))
call assert_equal('aristotle:physics', s:candidates[0].word)

let g:vimtex_complete_bib.simple = 1
let s:candidates = v:lua.require('vimtex.test').completion('\textcite[5--10]{', 'aristotle:p')
call assert_equal(2, len(s:candidates))
call assert_equal('aristotle:physics', s:candidates[0].word)

call v:lua.require('vimtex.test').finished()
