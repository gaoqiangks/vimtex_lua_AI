source common.vim

EditConcealed test-wiki.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texWikiZone', 6, 1))
" call assert_true(v:lua.require('vimtex.syntax').in_group('markdownHeader', 7, 1))

call v:lua.require('vimtex.test').finished()
