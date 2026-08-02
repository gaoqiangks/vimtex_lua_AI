source common.vim

EditConcealed test-latex3.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texE3Zone', 7, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texE3Func', 7, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texE3Var', 7, 15))

call v:lua.require('vimtex.test').finished()
