source common.vim

EditConcealed test-quantikz.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
