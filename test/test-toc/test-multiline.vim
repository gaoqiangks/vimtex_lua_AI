set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

set foldenable
let g:vimtex_fold_enabled = 1

silent edit test-multiline.tex

if empty($INMAKE) | finish | endif

let s:toc = v:lua.require('vimtex.toc').get_entries(v:false)
call assert_equal(3, len(s:toc))
call assert_equal(
      \ 'This is a really long section title which is hard-wrapped after '
      \ . '80 characters or so to keep the source code readable',
      \ s:toc[2].title)

call v:lua.require('vimtex.test').finished()
