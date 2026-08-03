set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

call v:lua.require('vimtex.log').set_silent()

if empty($INMAKE) | finish | endif

" Open included file should create two states (main and included)
call assert_equal(len(v:lua.require('vimtex.state').list_all()), 0)
silent edit included.tex
call assert_equal(len(v:lua.require('vimtex.state').list_all()), 2)
call assert_true(v:lua.require('vimtex.state').get(b:vimtex_local.sub_id).__lazy)
call assert_false(has_key(v:lua.require('vimtex.state').get(b:vimtex_local.sub_id), 'compiler'))

" If we toggle to the included state then wipe it, we should not cleanup the
" main state
VimtexToggleMain
call assert_false(get(b:vimtex, '__lazy', v:false))
call assert_true(has_key(b:vimtex, 'compiler'))
bwipeout
call assert_equal(len(v:lua.require('vimtex.state').list_all()), 1)

"
" The main state should be cleaned up when we exit, though!
"

let g:test = 0
augroup Testing
  autocmd!
  autocmd User VimtexEventQuit let g:test += 1
augroup END

function! Finalize() abort
  call assert_equal(g:test, 1)
  call v:lua.require('vimtex.test').finished()
endfunction

autocmd Testing VimLeave * call Finalize()
quitall!
