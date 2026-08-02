source common.vim

EditConcealed test-tcolorbox.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texTCBZone', 49, 1))

call v:lua.require('vimtex.test').finished()
