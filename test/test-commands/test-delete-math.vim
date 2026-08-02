set nocompatible
set runtimepath^=../..
filetype plugin on
syntax on


" ds$  /  Delete surrounding math ($...$ and \[...\])
call v:lua.require('vimtex.test').keys('f$ds$',
      \ 'for $ 2+2 = 4 = 3 $ etter',
      \ 'for 2+2 = 4 = 3 etter')
call v:lua.require('vimtex.test').keys('jds$',
      \[
      \ 'asd $',
      \ '2+2 = 4',
      \ '$ asd',
      \],
      \[
      \ 'asd',
      \ '2+2 = 4',
      \ 'asd',
      \])
call v:lua.require('vimtex.test').keys('ds$',
      \[
      \ '\[',
      \ '2+2 = 4',
      \ '\]',
      \], '2+2 = 4')


call v:lua.require('vimtex.test').finished()
