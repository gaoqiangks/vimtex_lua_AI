set nocompatible
set runtimepath^=../..
filetype plugin on
syntax on

nnoremap q :qall!<cr>

silent edit test-toggle-math-starred.tex

" Toggling a starred environment to a math delimiter must not append a star
" to the delimiter (cf. #3274)
normal! 4G
call v:lua.require('vimtex.env').toggle_math()
call assert_equal('$1 + 2 = 3$', getline(4))

call v:lua.require('vimtex.test').finished()
