source common.vim

EditConcealed test-sagetex.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
