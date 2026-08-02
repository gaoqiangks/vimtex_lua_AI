source common.vim

EditConcealed test-amsthm.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdThmStyle', 4, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texThmStyleArg', 4, 15))
call assert_true(v:lua.require('vimtex.syntax').in_group('texNewthmOptNumberby', 5, 32))
call assert_true(v:lua.require('vimtex.syntax').in_group('texNewthmOptCounter', 6, 19))

call assert_true(v:lua.require('vimtex.syntax').in_group('texProofEnvBgn', 23, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texProofEnvOpt', 23, 15))

call assert_true(v:lua.require('vimtex.syntax').in_group('texTheoremEnvBgn', 11, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTheoremEnvBgn', 15, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTheoremEnvBgn', 19, 1))

call assert_true(v:lua.require('vimtex.syntax').in_group('texTheoremEnvOpt', 11, 36))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdRefConcealed', 11, 42))
call assert_true(v:lua.require('vimtex.syntax').in_group('texRefConcealedArg', 11, 47))

call v:lua.require('vimtex.test').finished()
