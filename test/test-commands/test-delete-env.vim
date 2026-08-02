set nocompatible
set runtimepath^=../..
filetype plugin on


" dse  /  Delete surrounding environment
call v:lua.require('vimtex.test').keys('dsedse',
      \[
      \ '\begin{test}',
      \ '  \begin{center} a \end{center}',
      \ '\end{test}',
      \], '   a ')


call v:lua.require('vimtex.test').finished()
