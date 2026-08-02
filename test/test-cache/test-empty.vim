set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'

call writefile([], 'empty.json')

try
  let s:cache = v:lua.require('vimtex.cache').open('empty')
catch
  call assert_report('Should not fail on empty cache file!')
finally
  call delete('empty.json')
endtry

call v:lua.require('vimtex.test').finished()
