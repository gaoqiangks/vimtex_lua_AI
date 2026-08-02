source common.vim

EditConcealed test-expl3.tex

if empty($INMAKE) | finish | endif

call assert_true(!v:lua.require('vimtex.syntax').in_group('texGroupError', 29, 1))

call assert_false(v:lua.require('vimtex.syntax').in_group('texSpecialChar', 72, 6))

call v:lua.require('vimtex.test').finished()
