source common.vim

Edit test-apacite.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
