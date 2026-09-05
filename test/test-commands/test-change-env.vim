set nocompatible
set runtimepath^=../..
filetype plugin on


" cse  /  Change surrounding environment
" .    /  Dot repeat
call v:lua.require('vimtex.test').keys("csebaz\<cr>}j.",
      \[
      \ '\begin{foo}',
      \ '  Foo',
      \ '\end{foo}',
      \ '',
      \ '\begin{bar}',
      \ '  Bar',
      \ '\end{bar}',
      \],
      \[
      \ '\begin{baz}',
      \ '  Foo',
      \ '\end{baz}',
      \ '',
      \ '\begin{baz}',
      \ '  Bar',
      \ '\end{baz}',
      \])

" Esc cancels the change, even after entering a new environment name
call v:lua.require('vimtex.test').keys("csebaz\<esc>",
      \[
      \ '\begin{foo}',
      \ '  Foo',
      \ '\end{foo}',
      \],
      \[
      \ '\begin{foo}',
      \ '  Foo',
      \ '\end{foo}',
      \])


call v:lua.require('vimtex.test').finished()
