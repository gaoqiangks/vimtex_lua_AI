set nocompatible
set runtimepath^=../..
filetype plugin indent on
syntax on

set shiftwidth=4
set expandtab

new
setfiletype tex
call setline(1, [
      \ '\begin{itemize}',
      \ '    \item first',
      \ '        continuation',
      \ '\end{itemize}',
      \])

call cursor(3, 1)
call feedkeys('A' . "\<CR>" . '\item' . "\<Esc>", 'xt')
call assert_equal('    \item', getline(4))

call v:lua.require('vimtex.test').finished()
