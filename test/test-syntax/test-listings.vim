source common.vim

EditConcealed test-listings.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texFileArg', 7, 28))
call assert_true(v:lua.require('vimtex.syntax').in_group('texLstZoneInline', 9, 14))

call assert_true(v:lua.require('vimtex.syntax').in_group('texLstZone', 15, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texLstZoneC', 23, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texLstZonePython', 30, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texLstZoneRust', 37, 1))

call assert_true(v:lua.require('vimtex.syntax').in_group('texLstsetArg', 42, 10))

call assert_true(v:lua.require('vimtex.syntax').in_group('texCmd', 46, 18))
call assert_true(v:lua.require('vimtex.syntax').in_group('texCmdSize', 47, 18))

call v:lua.require('vimtex.test').finished()
