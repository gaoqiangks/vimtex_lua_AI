set nocompatible
set noswapfile
set runtimepath^=../..
filetype plugin on

call setline(1, [
      \ '\begin{document}',
      \ 'Outside ordinary environments.',
      \ '\end{document}',
      \ ])
setfiletype tex
call cursor(2, 1)

lua << EOF
local message
local log = require "vimtex.log"
local original = log.info
log.info = function(text)
  message = text
end

local mapping = vim.fn.maparg("<plug>(vimtex-env-change)", "n", false, true)
assert(type(mapping.callback) == "function")
mapping.callback()
log.info = original

assert(message == "No surrounding environment found")
EOF

call v:lua.require('vimtex.test').finished()
