source common.vim

EditConcealed test-core.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texNewenvParm', 37, 36))

call assert_true(v:lua.require('vimtex.syntax').in_group('texVerbZoneInline', 45, 36))

call assert_true(v:lua.require('vimtex.syntax').in_group('texAuthorArg', 65, 20))
call assert_true(v:lua.require('vimtex.syntax').in_group('texDelim', 65, 39))

call assert_true(v:lua.require('vimtex.syntax').in_group('texNewthmArgPrinted', 39, 23))
" call assert_true(v:lua.require('vimtex.syntax').in_group('texTheoremEnvOpt', 115, 18))

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathTextConcArg', 106, 59))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathTextConcArg', 105, 59))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdBibitem', 124, 3))
call assert_true(v:lua.require('vimtex.syntax').in_group('texBibitemArg', 124, 13))
call assert_true(v:lua.require('vimtex.syntax').in_group('texBibitemOpt', 125, 13))

call assert_true(v:lua.require('vimtex.syntax').in_group('texTabularChar', 133, 5))
call assert_true(v:lua.require('vimtex.syntax').in_group('texSpecialChar', 133, 6))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdAccent', 133, 11))

call v:lua.require('vimtex.test').finished()
