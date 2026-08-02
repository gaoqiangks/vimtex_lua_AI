set nocompatible
let &rtp = '../..,' . &rtp
let &rtp .= ',../../after'
filetype plugin indent on
syntax enable

set nomore
set expandtab
set shiftwidth=2

let g:vimtex_imaps_leader = ';'
let g:vimtex_imaps_disabled = ['a']
call v:lua.require('vimtex.imaps').add_map({'lhs' : 'vv', 'rhs' : '\vec{'})
call v:lua.require('vimtex.imaps').add_map({
  \ 'lhs' : 'test',
  \ 'rhs' : 'tested',
  \ 'leader' : '',
  \ 'wrapper' : 'vimtex#imaps#wrap_trivial',
  \})
call v:lua.require('vimtex.imaps').add_map({
  \ 'lhs' : 'cool',
  \ 'rhs' : '\item',
  \ 'leader' : '',
  \ 'wrapper' : 'vimtex#imaps#wrap_environment',
  \ 'context' : ['enumerate'],
  \})

" Test ;b -> \beta
call v:lua.require('vimtex.test').keys('$i;b;;', '$2+2 = $', '$2+2 = \beta;;$')

" Test #bv -> \mathbf{v}
call v:lua.require('vimtex.test').keys('$i#bv', '$2+2 = $', '$2+2 = \mathbf{v}$')

" Should not gobble a character outside of math mode
call v:lua.require('vimtex.test').keys('$a#bv', '$2+2 = $', '$2+2 = $#bv')

" Test ;; -> ; (leader escape)
call v:lua.require('vimtex.test').keys('$i;;', '$;; = $', '$;; = ;;$')

" Test ;a -> ;a (disabled imap)
call v:lua.require('vimtex.test').keys('$i;a', '$a = $', '$a = ;a$')

" Test test -> tested
call v:lua.require('vimtex.test').keys('itest', '', 'tested')

" Test inside math: ;vv -> \vec{
call v:lua.require('vimtex.test').keys('A;vvf}\cdot;vvf}$',
      \ '$|f| = ',
      \ '$|f| = \vec{f}\cdot\vec{f}$')

" Test outside math: ;vv -> ;vv
call v:lua.require('vimtex.test').keys('A --- ;vv',
      \ '$|f| = \vec{f}\cdot\vec{f}$',
      \ '$|f| = \vec{f}\cdot\vec{f}$ --- ;vv')

" Test inside itemize: cool -> cool
call v:lua.require('vimtex.test').keys('ocool',
      \['\begin{itemize}', '\end{itemize}'],
      \['\begin{itemize}', '  cool', '\end{itemize}'])

" Test inside itemize: cool -> \item
call v:lua.require('vimtex.test').keys('ocool',
      \['\begin{enumerate}', '\end{enumerate}'],
      \['\begin{enumerate}', '  \item', '\end{enumerate}'])

" Test inside align environment: ;b -> \beta (#1648)
call v:lua.require('vimtex.syntax.packages').load('amsmath')
call v:lua.require('vimtex.test').keys('o;b',
      \ ['\begin{align}', '\end{align}'],
      \ ['\begin{align}', '  \beta', '\end{align}'])

call v:lua.require('vimtex.test').finished()
