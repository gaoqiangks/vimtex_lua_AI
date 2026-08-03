set nocompatible
set runtimepath^=../..
filetype plugin indent on

function! EnvChangeHook(name) abort
  return a:name ==# 'prop' ? 'proposition' : a:name
endfunction
let g:vimtex_env_change_hook = 'EnvChangeHook'

silent edit test-change-hook.tex

lua << EOF
local env = require "vimtex.env"
local ui = require "vimtex.ui"

assert(env.apply_change_hook "prop" == "proposition")

env.change_hook = function(name)
  return name == "theo" and "theorem" or name
end
ui.input = function()
  return "theo"
end

vim.api.nvim_win_set_cursor(0, { 4, 0 })
local mapping = vim.fn.maparg("<plug>(vimtex-env-change)", "n", false, true)
assert(type(mapping.callback) == "function")
mapping.callback()

assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 2, 5, false), {
  "\\begin{theorem}",
  "  Hello",
  "\\end{theorem}",
}))

env.change_hook = function()
  return ""
end
assert(env.apply_change_hook "proof" == "proof")
EOF

call v:lua.require('vimtex.test').finished()
