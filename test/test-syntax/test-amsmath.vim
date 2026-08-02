source common.vim

EditConcealed test-amsmath.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdDeclmathoper', 4, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texDeclmathoperArgName', 4, 22))
call assert_true(v:lua.require('vimtex.syntax').in_group('texDeclmathoperArgBody', 4, 27))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdOpname', 5, 18))
call assert_true(v:lua.require('vimtex.syntax').in_group('texOpnameArg', 5, 32))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdNumberWithin', 7, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texNumberWithinArg1', 7, 15))
call assert_true(v:lua.require('vimtex.syntax').in_group('texNumberWithinArg2', 7, 25))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdSubjClass', 9, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texSubjClassOpt', 9, 12))
call assert_true(v:lua.require('vimtex.syntax').in_group('texSubjClassArg', 9, 18))

call v:lua.require('vimtex.test').finished()
