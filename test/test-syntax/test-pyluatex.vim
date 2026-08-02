source common.vim

EditConcealed test-pyluatex.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('pythonString', 7, 13))
call assert_true(v:lua.require('vimtex.syntax').in_group('pythonString', 11, 13))
call assert_true(v:lua.require('vimtex.syntax').in_group('pythonString', 15, 13))

call v:lua.require('vimtex.test').finished()
