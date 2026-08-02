source common.vim

EditConcealed test-fontawesome5.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
