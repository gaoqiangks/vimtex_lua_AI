set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

if v:lua.require('vimtex.util').is_win() | quitall | endif


let s:output = v:lua.require('vimtex.jobs').capture("echo 'a\nb'")
call assert_equal(['a', 'b'], s:output)

let s:output = v:lua.require('vimtex.jobs').capture("echobaad foobar")
call assert_match('not found', s:output[0])


call v:lua.require('vimtex.test').finished()
