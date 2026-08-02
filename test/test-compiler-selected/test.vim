set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore

silent edit test.tex

call v:lua.require('vimtex.parser').selection_to_texfile({
      \ 'range': [10, 12],
      \ 'name': 'output1',
      \})

call v:lua.require('vimtex.parser').selection_to_texfile({
      \ 'range': [10, 12],
      \ 'name': 'output2',
      \ 'template_name': 'NONE',
      \})

call v:lua.require('vimtex.parser').selection_to_texfile({
      \ 'range': [10, 12],
      \ 'name': 'output3',
      \ 'template_name': 'template.tex',
      \})

quitall!
