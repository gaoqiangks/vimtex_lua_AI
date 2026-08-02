set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

if empty($INMAKE) | finish | endif

lua << EOF
local compiler = require "vimtex.compiler"

local function fake_state(tex, signature, running)
  return {
    tex = tex,
    compiler = {
      get_output_signature = function(extension)
        return extension == "aux" and signature or ""
      end,
      is_running = function()
        return running
      end,
    },
  }
end

local function names(states)
  local result = vim.tbl_map(function(state) return state.tex end, states)
  table.sort(result)
  return result
end

local a = fake_state("/a/note.tex", "/out/note.aux", true)
local b = fake_state("/b/note.tex", "/out/note.aux", true)
local c = fake_state("/c/note.tex", "/out/note.aux", false)
local d = fake_state("/d/other.tex", "/out/other.aux", true)
local states = { a, b, c, d }

vim.fn.assert_equal({}, names(compiler.get_output_clashes(d.compiler, { d })))
vim.fn.assert_equal({ "/b/note.tex" }, names(compiler.get_output_clashes(a.compiler, states)))
vim.fn.assert_equal({}, names(compiler.get_output_clashes(c.compiler, { c, d })))
local empty = fake_state("/e/note.tex", "", true)
vim.fn.assert_equal({}, names(compiler.get_output_clashes(empty.compiler, states)))
local no_status = { tex = "/f/note.tex", compiler = { get_output_signature = function() return "/out/note.aux" end } }
vim.fn.assert_equal({ "/b/note.tex" }, names(compiler.get_output_clashes(a.compiler, vim.list_extend(states, { no_status }))))
EOF

call v:lua.require('vimtex.test').finished()
