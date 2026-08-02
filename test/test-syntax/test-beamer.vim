source common.vim

Edit test-beamer.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texVerbZone', 6, 1))

call v:lua.require('vimtex.test').finished()
