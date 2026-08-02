source common.vim

EditConcealed test-minted.tex

if empty($INMAKE) | finish | endif

" Minted inside \paragraphs (#1537)
call assert_true(v:lua.require('vimtex.syntax').in_group('javaScopeDecl', 72, 3))

" Newminted on unrecognized languages (#1616)
call assert_true(v:lua.require('vimtex.syntax').in_group('texMintedZoneLog', 112, 1))
call assert_true(v:lua.require('vimtex.syntax').in_group('texMintedZoneShellsession', 116, 1))

" " Doing :e should not destroy nested syntax and similar
" call assert_true(v:lua.require('vimtex.syntax').in_group('pythonFunction', 38, 5))
" edit
" call assert_true(v:lua.require('vimtex.syntax').in_group('pythonFunction', 38, 5))

call assert_true(v:lua.require('vimtex.syntax').in_group('texMintedZoneJson', 121, 1))

call v:lua.require('vimtex.test').finished()
