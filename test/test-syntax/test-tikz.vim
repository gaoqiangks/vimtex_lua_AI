source common.vim

EditConcealed test-tikz.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texTikzSemicolon', 66, 61))
call assert_true(v:lua.require('vimtex.syntax').in_group('texTikzZone', 66, 61))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdAxis', 71, 9))

call v:lua.require('vimtex.test').finished()
