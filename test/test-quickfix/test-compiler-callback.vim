set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

call v:lua.require('vimtex.log').set_silent()
silent edit ../example-quickfix/main.tex

lua << EOF
local owner = vim.api.nvim_get_current_buf()
local state = require("vimtex.state").get(vim.b.vimtex_id)
local compiler = state.compiler

vim.cmd "enew"
local current = vim.api.nvim_get_current_buf()
local event_buffer = -1
vim.api.nvim_create_autocmd("User", {
  pattern = "VimtexEventCompileSuccess",
  once = true,
  callback = function(args)
    event_buffer = args.buf
  end,
})

-- A compiler may finish while another, unrelated buffer is current.  The log
-- must still be parsed in the owning project's context.
require("vimtex.compiler").callback(2, compiler)

local counts = { E = 0, W = 0 }
for _, entry in ipairs(vim.fn.getqflist()) do
  counts[entry.type] = (counts[entry.type] or 0) + 1
end
assert(owner == event_buffer)
assert(current == vim.api.nvim_get_current_buf())
assert(counts.E == 7, vim.inspect(counts))
assert(counts.W == 18, vim.inspect(counts))

-- Every completed build must replace stale entries, even when the previous
-- quickfix list was modified after the last callback.
vim.fn.setqflist({ { text = "stale", type = "E" } }, "r")
require("vimtex.compiler").callback(2, compiler)
counts = { E = 0, W = 0 }
for _, entry in ipairs(vim.fn.getqflist()) do
  counts[entry.type] = (counts[entry.type] or 0) + 1
end
assert(counts.E == 7, vim.inspect(counts))
assert(counts.W == 18, vim.inspect(counts))

-- A failed parser invocation must not leak its temporary errorformat into the
-- current buffer; otherwise later builds can be parsed with the wrong rules.
local errorformat = vim.bo.errorformat
local ok = pcall(require("vimtex.qf.util").caddfile, "/file/does/not/exist", errorformat)
assert(not ok)
assert(errorformat == vim.bo.errorformat)
EOF

call v:lua.require('vimtex.test').finished()
