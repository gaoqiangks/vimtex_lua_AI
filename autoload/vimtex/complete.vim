function! vimtex#complete#omnifunc(findstart, base) abort
  return v:lua.require('vimtex.complete').omnifunc(a:findstart, a:base)
endfunction
