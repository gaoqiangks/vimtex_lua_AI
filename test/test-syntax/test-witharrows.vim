source common.vim

EditConcealed test-witharrows.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
