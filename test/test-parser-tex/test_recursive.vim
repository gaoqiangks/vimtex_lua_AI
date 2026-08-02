set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore
set hidden

nnoremap q :qall!<cr>

call v:lua.require('vimtex.log').set_silent()

if empty($INMAKE) | finish | endif

silent! edit test_recursive.tex
call b:vimtex.get_sources()

let s:log = v:lua.require('vimtex.log').get()
call assert_equal(1, len(s:log))
call assert_equal('Recursive file inclusion!', s:log[0].msg[0])

call v:lua.require('vimtex.test').finished()
