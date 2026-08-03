set nocompatible
set runtimepath^=../..
filetype plugin indent on
syntax on

set shiftwidth=2
set expandtab

let g:vimtex_env_toggle_math_map = {
      \ '$': 'equation',
      \ 'equation': '$',
      \}

new
setfiletype tex

call setline(1, 'Text $1+1=2$, next')
normal! 1Gf1
call v:lua.require('vimtex.env').toggle_math()
call assert_equal([
      \ 'Text',
      \ '\begin{equation}',
      \ '  1+1=2,',
      \ '\end{equation}',
      \ 'next',
      \], getline(1, '$'))

normal! 3G
call v:lua.require('vimtex.env').toggle_math()
call assert_equal(['Text $1+1=2$, next'], getline(1, '$'))

call setline(1, 'Text $x$?! next')
normal! 1Gfx
call v:lua.require('vimtex.env').toggle_math()
call assert_equal([
      \ 'Text',
      \ '\begin{equation}',
      \ '  x?!',
      \ '\end{equation}',
      \ 'next',
      \], getline(1, '$'))

call setline(1, [
      \ '\begin{equation}',
      \ '  x',
      \ '\end{equation}。 next',
      \])
silent 4,$delete _
normal! 2G
call v:lua.require('vimtex.env').toggle_math()
call assert_equal(['$x$。 next'], getline(1, '$'))

call setline(1, '\begin{equation}1+1=2,\end{equation}')
normal! 1Gf1
call v:lua.require('vimtex.env').toggle_math()
call assert_equal(['$1+1=2$,'], getline(1, '$'))

call v:lua.require('vimtex.test').finished()
