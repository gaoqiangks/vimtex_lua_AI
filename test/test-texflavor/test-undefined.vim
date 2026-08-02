set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

silent edit plaintex.tex
call assert_equal('tex', &filetype)

call v:lua.require('vimtex.test').finished()
