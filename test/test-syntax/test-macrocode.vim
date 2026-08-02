source common.vim

Edit test-macrocode.dtx

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
