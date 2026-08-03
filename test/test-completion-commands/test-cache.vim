set nocompatible
set noswapfile
let &runtimepath = '../..,' . &runtimepath
filetype plugin on

let s:file = tempname() . '.tex'
call writefile([
      \ '\documentclass{article}',
      \ '\begin{document}',
      \ '\end{document}',
      \ ], s:file)
execute 'edit' fnameescape(s:file)

lua << EOF
local complete = require "vimtex.complete"
-- Returned candidates must not mutate the cached source.
local theorem = complete.complete("env", "theorem", "\\begin")
assert(#theorem > 0)
theorem[1].word = "mutated"
assert(complete.complete("env", "theorem", "\\begin")[1].word ~= "mutated")

-- Building the environment cache also builds the command cache.
local first = complete.complete("cmd", "cached", "\\cached")
assert(#first == 0)
EOF

call append(1, '\let\cachedtest=\relax')
write

lua << EOF
local result = require("vimtex.complete").complete("cmd", "cached", "\\cached")
assert(#result == 1 and result[1].word == "cachedtest", vim.inspect(result))
EOF

call delete(s:file)
call v:lua.require('vimtex.test').finished()
