source common.vim

EditConcealed test-chemformula.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texFootnoteArg', 25, 48))
call assert_true(!v:lua.require('vimtex.syntax').in_group('texCHText', 25, 48))

call v:lua.require('vimtex.test').finished()
