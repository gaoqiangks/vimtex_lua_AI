source common.vim

EditConcealed test-mathtools.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 7, 1))

call v:lua.require('vimtex.test').finished()
