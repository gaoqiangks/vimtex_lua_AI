source common.vim

EditConcealed test-cases.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
