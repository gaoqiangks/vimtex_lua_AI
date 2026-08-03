set nocompatible
set noswapfile
let &runtimepath = '../..,' . &runtimepath
filetype plugin on
syntax on

let g:vimtex_delim_stopline = 500
let g:vimtex_delim_timeout = 300

call setline(1, [
      \ '\begin{document}',
      \ '\begin{itemize}',
      \ '\item nested',
      \ '\end{itemize}',
      \ 'outside environments',
      \ '\end{document}',
      \ ])
call cursor(5, 1)

lua << EOF
local delim = require "vimtex.delim"
local original = delim.get_matching
local document_calls = 0
delim.get_matching = function(opening)
  if opening.name == "document" then
    document_calls = document_calls + 1
  end
  return original(opening)
end

local pair = require("vimtex.env").get_surrounding "normal"
delim.get_matching = original

assert(vim.tbl_isempty(pair[1]), "document is not a surrounding environment")
assert(document_calls == 0, "document must not be matched")
EOF

call v:lua.require('vimtex.test').finished()
