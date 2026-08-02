set nocompatible
set runtimepath^=../..
filetype plugin indent on
syntax on

set shiftwidth=2
set expandtab


" cs$ -> $
call v:lua.require('vimtex.test').keys("jjcs$$\<cr>",
      \ [ 'text',
      \   '\[',
      \   '  math',
      \   '\]',
      \   'text' ],
      \ ['text $math$ text'])

" cs$ -> $
call v:lua.require('vimtex.test').keys("3jcs$$\<cr>",
      \ [ '  indented text',
      \   '',
      \   '  \[',
      \   '          m = a t_h',
      \   '  \]',
      \   '  More text' ],
      \ [ '  indented text',
      \   '',
      \   '  $m = a t_h$ More text'])

" cs$ -> $
call v:lua.require('vimtex.test').keys("jjcs$$\<cr>",
      \ [ '  indented text',
      \   '  \[',
      \   '          m = a t_h',
      \   '  \]',
      \   '',
      \   '  More text' ],
      \ [ '  indented text $m = a t_h$',
      \   '',
      \   '  More text'])

" cs$ -> \[
call v:lua.require('vimtex.test').keys("f$cs$\\[\<cr>",
      \ ['text $math$ text'],
      \ ['text',
      \  '\[',
      \  '  math',
      \  '\]',
      \  'text'])

" cs$ -> \[
call v:lua.require('vimtex.test').keys("cs$\\[\<cr>",
      \ ['$math$ text'],
      \ ['\[',
      \  '  math',
      \  '\]',
      \  'text'])

" cs$ -> \[
call v:lua.require('vimtex.test').keys("jcs$\\[\<cr>",
      \ ['text',
      \  '$',
      \  'math',
      \  '$',
      \  'text'],
      \ ['text',
      \  '\[',
      \  '  math',
      \  '\]',
      \  'text'])

" cs$ -> \[
call v:lua.require('vimtex.test').keys("f$cs$\\[\<cr>",
      \ ['text $',
      \  'math',
      \  '$ text'],
      \ ['text',
      \  '\[',
      \  '  math',
      \  '\]',
      \  'text'])

" cs$ -> \[
call v:lua.require('vimtex.test').keys("jcs$\\[\<cr>",
      \ ['  text $f(x)',
      \ ' = 1$ text'],
      \ ['  text',
      \  '  \[',
      \  '    f(x)',
      \  '    = 1',
      \  '  \]',
      \  '  text'])

" cs$ -> \(
call v:lua.require('vimtex.test').keys("jjcs$\\(\<cr>",
      \ ['text',
      \  '\[',
      \  '  math',
      \  '\]',
      \  'text' ],
      \ ['text',
      \  '\(',
      \  '  math',
      \  '\)',
      \  'text' ])


call v:lua.require('vimtex.test').finished()
