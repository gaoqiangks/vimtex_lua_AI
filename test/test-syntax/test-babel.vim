source common.vim

EditConcealed test-babel.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
