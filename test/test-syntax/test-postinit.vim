source common.vim

try
  runtime syntax/tex.vim
catch
  call assert_true(0, 'Bare include of VimTeX syntax should work!')
endtry

call v:lua.require('vimtex.test').finished()
