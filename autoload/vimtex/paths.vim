function! vimtex#paths#pushd(path) abort
  return v:lua.require('vimtex.paths').pushd(a:path)
endfunction

function! vimtex#paths#popd() abort
  return v:lua.require('vimtex.paths').popd()
endfunction
