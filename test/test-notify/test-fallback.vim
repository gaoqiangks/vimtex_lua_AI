set nocompatible
set runtimepath^=../..

lua << EOF
local calls = {}
vim.notify = function(message, level, opts)
  calls[#calls + 1] = { message = message, level = level, opts = opts }
end

vim.g.vimtex_notify_enabled = 1
require("vimtex.notify").setup()
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompiling" })
assert(calls[#calls].message:find("Compiling...", 1, true))
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompileFailed" })
assert(calls[#calls].message == "Compile Failed")
assert(calls[#calls].opts.replace == nil)

vim.cmd "VimtexNotifyToggle"
assert(vim.g.vimtex_notify_enabled == 0)
EOF

call v:lua.require('vimtex.test').finished()
