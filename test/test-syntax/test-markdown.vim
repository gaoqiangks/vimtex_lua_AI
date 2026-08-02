source common.vim

EditConcealed test-markdown.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texMarkdownZone', 7, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('markdownItalic', 7, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('markdownLink', 11, 12))
call assert_true(v:lua.require('vimtex.syntax').in_group('texFileArg', 16, 16))

call v:lua.require('vimtex.test').finished()
