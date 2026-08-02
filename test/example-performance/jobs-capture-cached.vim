set nocompatible
set runtimepath^=~/.local/plugged/vimtex
filetype plugin on

nnoremap q :qall!<cr>

let s:cmd = 'uname -sr'

let s:time = v:lua.require('vimtex.profile').time()
for s:x in range(100)
  call v:lua.require('vimtex.jobs').capture(s:cmd)
endfor

let s:time = v:lua.require('vimtex.profile').time(s:time)
for s:x in range(100)
  call v:lua.require('vimtex.jobs').cached(s:cmd)
endfor

call v:lua.require('vimtex.profile').time(s:time)

quitall!
