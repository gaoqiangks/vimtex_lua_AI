set nocompatible
set runtimepath^=../..
filetype plugin on

silent edit test.tex

lua << EOF
local component = require "vimtex.lualine"

assert(component.status() == "")
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompiling" })
assert(component.status():find("Compiling", 1, true))

vim.fn.setqflist({
  { text = "first error", type = "E" },
  { text = "first warning", type = "W" },
  { text = "second warning", type = "W" },
}, "r")
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompileFailed" })
assert(component.status() == "✗ Failed E:1 W:2")
assert(component.color().fg == "#f7768e")

local tex_buffer = vim.api.nvim_get_current_buf()
vim.cmd "tabnew"
assert(component.status() == "")
vim.cmd "tabclose"
assert(vim.api.nvim_get_current_buf() == tex_buffer)
assert(component.status() == "✗ Failed E:1 W:2")

vim.fn.setqflist({}, "r")
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompileSuccess" })
assert(component.status() == "✓ Compiled E:0 W:0")

local options = vim.g.vimtex_lualine
options.show_counts = false
vim.g.vimtex_lualine = options
assert(component.status() == "✓ Compiled")
EOF

call v:lua.require('vimtex.test').finished()
