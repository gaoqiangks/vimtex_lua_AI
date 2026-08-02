source common.vim

EditConcealed test-ieeetrantools.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 8, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 13, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 24, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 31, 1))

call v:lua.require('vimtex.test').finished()
