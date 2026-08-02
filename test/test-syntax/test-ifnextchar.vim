source common.vim

EditConcealed test-ifnextchar.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texConditionalINCChar', 3, 28))
call assert_equal([], v:lua.require('vimtex.syntax').stack(8, 1))

call v:lua.require('vimtex.test').finished()
