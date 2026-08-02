set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

silent edit test-beamer.tex

if empty($INMAKE) | finish | endif

let s:toc = v:lua.require('vimtex.toc').get_entries(v:false)
call assert_equal(14, len(s:toc))

call assert_equal('Frame 3: A title here - Subtitle', s:toc[6].title)
call assert_equal(21, s:toc[6].line)

call assert_equal('Frame 4: title - subtitle', s:toc[7].title)
call assert_equal('Frame 5: title', s:toc[8].title)
call assert_equal('Frame 6: subtitle', s:toc[9].title)

call assert_equal('Frame 9: Finito again', s:toc[13].title)

call v:lua.require('vimtex.test').finished()
