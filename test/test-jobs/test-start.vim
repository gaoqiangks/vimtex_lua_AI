set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

if v:lua.require('vimtex.util').is_win() | quitall | endif


let s:job = v:lua.require('vimtex.jobs').start('sleep 100')
call assert_true(v:lua.require('vimtex.jobs').is_running(s:job))
call v:lua.require('vimtex.jobs').stop(s:job)
call assert_false(v:lua.require('vimtex.jobs').is_running(s:job))
call v:lua.require('vimtex.jobs').stop(s:job)


call v:lua.require('vimtex.test').finished()
