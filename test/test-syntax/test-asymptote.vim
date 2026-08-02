source common.vim

set runtimepath^=.

EditConcealed test-asymptote.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.test').finished()
