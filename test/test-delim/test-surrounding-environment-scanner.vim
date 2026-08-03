set nocompatible
set noswapfile
let &runtimepath = '../..,' . &runtimepath
filetype plugin on
syntax on

call setline(1, [
      \ '\begin{document}',
      \ '% \begin{fake}',
      \ '\begin{theorem}',
      \ '\begin{enumerate}',
      \ '\item nested',
      \ '\end{enumerate}',
      \ '\end{theorem}',
      \ 'outside environments',
      \ '\end{document}',
      \ ])

lua << EOF
local env = require "vimtex.env"

local function surrounding(line, column, whitelist)
  vim.fn.cursor(line, column or 1)
  return require("vimtex.delim").get_surrounding(
    "env_tex",
    whitelist and { whitelist = whitelist } or nil
  )
end

local pair = surrounding(5)
assert(pair[1].name == "enumerate" and pair[2].lnum == 6)

pair = surrounding(5, 1, { "theorem" })
assert(pair[1].name == "theorem" and pair[2].lnum == 7)

-- A cursor on either delimiter is still inside the environment.
pair = surrounding(4, 5)
assert(pair[1].name == "enumerate" and pair[2].lnum == 6)
pair = surrounding(6, 5)
assert(pair[1].name == "enumerate" and pair[2].lnum == 6)

pair = surrounding(8)
assert(vim.tbl_isempty(pair[1]), "document is not an editable environment")
EOF

call v:lua.require('vimtex.test').finished()
