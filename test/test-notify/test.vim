set nocompatible
set runtimepath^=../..
filetype plugin on

let g:vimtex_notify_enabled = 1

lua << EOF
_G.notify_calls = {}
package.preload.notify = function()
  local next_id = 0
  return {
    instance = function()
      return function(message, level, opts)
        next_id = next_id + 1
        _G.notify_calls[#_G.notify_calls + 1] = {
          message = message,
          level = level,
          opts = opts,
        }
        return next_id
      end
    end,
  }
end
EOF

silent edit test.tex

lua << EOF
assert(vim.fn.exists ":VimtexNotifyToggle" == 2)
assert(vim.fn.exists ":VimtexNotifyEnable" == 2)
assert(vim.fn.exists ":VimtexNotifyDisable" == 2)

vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompiling" })
assert(notify_calls[#notify_calls].message:find("Compiling...", 1, true))
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompileSuccess" })
assert(notify_calls[#notify_calls].message == "Compile Success")
assert(notify_calls[#notify_calls].opts.replace ~= nil)

vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCleanFinished" })
assert(notify_calls[#notify_calls].message == "Clean Success")

vim.cmd "VimtexNotifyDisable"
assert(vim.g.vimtex_notify_enabled == 0)
local count = #notify_calls
vim.api.nvim_exec_autocmds("User", { pattern = "VimtexEventCompiling" })
assert(#notify_calls == count)

vim.cmd "VimtexNotifyEnable"
assert(vim.g.vimtex_notify_enabled == 1)
EOF

call v:lua.require('vimtex.test').finished()
