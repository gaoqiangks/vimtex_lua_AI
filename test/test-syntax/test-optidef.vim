source common.vim

EditConcealed test-optidef.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 7, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 11, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 15, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 19, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 23, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 27, 1))

call v:lua.require('vimtex.test').finished()
