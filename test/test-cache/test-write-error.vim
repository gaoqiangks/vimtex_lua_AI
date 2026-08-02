set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

nnoremap q :qall!<cr>

let g:vimtex_cache_root = '.'

call v:lua.require('vimtex.log').set_silent()

if has('nvim')
  let s:cache_name = 'test-write-error'
  let s:cache_file = s:cache_name . '.json'
  lua << EOF
  local cache = require('vimtex.cache').open('test-write-error')
  cache:set('bad', function() end)
  cache:write()
EOF

  let s:log = v:lua.require('vimtex.log').get()
  call assert_equal(1, len(s:log))
  if len(s:log) > 0
    call assert_equal(
          \ printf('Could not encode VimTeX cache %s', s:cache_name),
          \ s:log[0].msg[0]
          \)
  endif

  if filereadable(s:cache_file) | call delete(s:cache_file) | endif
endif

call v:lua.require('vimtex.test').finished()
