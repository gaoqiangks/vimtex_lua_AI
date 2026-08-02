source common.vim

let g:vimtex_syntax_conceal = {
      \ 'sections' : 1,
      \}

EditConcealed! test-hyperref.tex

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_group('texUrlArg', 6, 25))
call assert_true(v:lua.require('vimtex.syntax').in_group('texRefArg', 17, 35))

call v:lua.require('vimtex.test').finished()
