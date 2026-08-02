set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

let s:output = v:lua.require('vimtex.util').win_clean_output(["Usuário\r"])
call assert_equal(["Usuário"], s:output)

call v:lua.require('vimtex.test').finished()
