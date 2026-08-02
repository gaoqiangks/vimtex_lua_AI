source common.vim

EditConcealed test-booktabs.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
