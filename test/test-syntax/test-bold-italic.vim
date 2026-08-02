source common.vim

" let g:vimtex_syntax_conceal = {'styles': 0}

EditConcealed test-bold-italic.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texStyleBoth', 5, 50))
call assert_true(v:lua.require('vimtex.syntax').in_group('texStyleBoth', 6, 50))
call assert_true(v:lua.require('vimtex.syntax').in_group('texStyleBoth', 8, 50))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdStyle', 7, 14))

call v:lua.require('vimtex.test').finished()
