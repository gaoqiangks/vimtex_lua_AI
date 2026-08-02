set nocompatible
set runtimepath^=../..
filetype plugin on


" dsc  /  Delete surrounding command
call v:lua.require('vimtex.test').keys('dsc', '\cmd{foo}', 'foo')
call v:lua.require('vimtex.test').keys("f{ldsc", '$ \ce{a > b} $', '$ a > b $')
call v:lua.require('vimtex.test').keys("f}hdsc", '$ \ce{a > b} $', '$ a > b $')


call v:lua.require('vimtex.test').finished()
