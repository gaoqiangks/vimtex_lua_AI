source common.vim

EditConcealed test-tabularx.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdTabularx', 6, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularxWidth', 6, 18))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularxPreamble', 6, 26))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdTabularx', 10, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularxWidth', 10, 18))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularxOpt', 10, 30))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularxPreamble', 10, 35))

call v:lua.require('vimtex.test').finished()
