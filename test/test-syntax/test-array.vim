source common.vim

EditConcealed test-array.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularCol', 10, 17))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularCol', 16, 18))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularMathdelim', 10, 24))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularCol', 32, 18))

call v:lua.require('vimtex.test').finished()
