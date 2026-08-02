set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'

lua << EOF
_G.SlowFuncWrapped = require('vimtex.cache').wrap(function(argument)
  vim.wait(100)
  return argument + 100
end, 'test-wrapper', { persistent = false })
_G.SlowFuncCacheHas = function(key)
  return require('vimtex.cache').open('test-wrapper'):has(key)
end
EOF

" First call is slow
let s:time = reltime()
call assert_equal(101, v:lua.SlowFuncWrapped(1))
call assert_inrange(0.09, 0.11, reltimefloat(reltime(s:time)))

" Second call is fast
let s:time = reltime()
call assert_equal(101, v:lua.SlowFuncWrapped(1))
call assert_inrange(0.0, 0.01, reltimefloat(reltime(s:time)))

" We can also open the cache directly
call assert_true(v:lua.SlowFuncCacheHas(1))

call v:lua.require('vimtex.test').finished()
