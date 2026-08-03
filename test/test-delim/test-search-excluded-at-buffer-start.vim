set nocompatible
set noswapfile
set runtimepath^=../..
filetype plugin on

let g:vimtex_delim_stopline = 500

call setline(1, '\begin{comment}')
call cursor(1, 1)

lua << EOF
local syntax = require "vimtex.syntax"
local original = syntax.in_group
syntax.in_group = function()
  return true
end

local found = require("vimtex.delim").get_prev(
  "env_tex",
  "open",
  { syn_exclude = "texComment" }
)
syntax.in_group = original

assert(
  vim.tbl_isempty(found),
  "excluded delimiter at buffer start must terminate: " .. vim.inspect(found)
)
EOF

call v:lua.require('vimtex.test').finished()
