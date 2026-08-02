source common.vim

EditConcealed test-mleftright.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathDelim', 7, 19))

call v:lua.require('vimtex.test').finished()
