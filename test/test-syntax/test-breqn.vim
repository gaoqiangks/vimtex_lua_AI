source common.vim

EditConcealed test-breqn.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMathZoneEnv', 9, 1))

call v:lua.require('vimtex.test').finished()

