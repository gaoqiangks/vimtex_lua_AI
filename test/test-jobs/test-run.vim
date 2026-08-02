set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

if v:lua.require('vimtex.util').is_win() | quitall | endif


let s:t0 = v:lua.require('vimtex.profile').time()
call v:lua.require('vimtex.jobs').run('sleep 0.2')
let s:t1 = v:lua.require('vimtex.profile').time()
call assert_true(s:t1 - s:t0 > 0.20)


call v:lua.require('vimtex.jobs').run('echo foobar')
call assert_equal(0, v:shell_error)

call v:lua.require('vimtex.jobs').run('echo (foobar')
call assert_notequal(0, v:shell_error)

call v:lua.require('vimtex.jobs').run('echofoobar')
call assert_equal(127, v:shell_error)



call v:lua.require('vimtex.test').finished()
