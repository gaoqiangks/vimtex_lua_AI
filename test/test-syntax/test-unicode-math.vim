source common.vim

EditConcealed test-unicode-math.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
