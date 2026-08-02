set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore

nnoremap q :qall!<cr>

silent edit test-comment.tex

if empty($INMAKE) | finish | endif

let s:toc = v:lua.require('vimtex.toc').get_entries(v:false)
call assert_equal(len(s:toc), 3)

" let s:i = 0
" for s:x in s:toc
"   echo s:i '--' s:x.title "\n"
"   let s:i += 1
" endfor

call v:lua.require('vimtex.test').finished()
