source common.vim

EditConcealed test-fixme.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdTodo', 140, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdWarning', 141, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdError', 142, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdFatal', 143, 2))
call assert_true(v:lua.require('vimtex.syntax').in_group('texFixmeErrorEnvBgn', 144, 10))

call v:lua.require('vimtex.test').finished()
