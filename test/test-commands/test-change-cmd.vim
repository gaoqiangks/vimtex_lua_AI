set nocompatible
set runtimepath^=../..
filetype plugin on


" csc  /  Change surrounding command
call v:lua.require('vimtex.test').keys("csctest\<cr>", '\cmd{foo}', '\test{foo}')


call v:lua.require('vimtex.test').finished()
