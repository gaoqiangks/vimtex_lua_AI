set nocompatible
set noswapfile
set runtimepath^=../..
let g:vimtex_compiler_enabled = 0
let g:vimtex_matchparen_enabled = 0
filetype plugin on
syntax on

silent edit test.tex

lua << EOF
local ok, message = xpcall(function()
  local delim = require "vimtex.delim"

  -- Matching must work independently of syntax highlighting, even when its
  -- rules do not recognize comments. Profiling also catches accidental synID
  -- calls, without relying on a timing threshold or a slow regular expression.
  vim.cmd "syntax clear"
  vim.cmd "syntax match texDelimRegression /./"
  vim.cmd "syntime on"

  local function check(lines)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    local last = #lines
    local closing_column = lines[last]:find("\\right", 1, true) or #lines[last]
    for _, cursor in ipairs { { 1, 0 }, { last, #lines[last] - 1 } } do
      vim.api.nvim_win_set_cursor(0, cursor)
      local opening = cursor[1] == 1 and cursor[2] == 0
      local current = delim.get_current("delim_math_modq", "both")
      local matching = delim.get_matching(current)
      local expected = opening and { last, closing_column } or { 1, 1 }
      vim.fn.assert_equal(expected, { matching.lnum, matching.cnum })
      vim.fn.assert_equal(cursor, vim.api.nvim_win_get_cursor(0))
    end
  end

  check { "(a % )", "b)" }
  check { "(a % (", "b)" }
  check { "(a % )", "% ( )", "b)" }
  check { [[(a \% b)]] }
  check { [[(a \\% )]], "b)" }
  check { [[(a \\\% b)]] }
  check { [[(a \% b % )]], "b)" }
  check { "(中文 % )", "b)" }
  check { "(a (nested) b)" }
  check { [[\left(a % \right)]], [[b\right)]] }

  local report = vim.api.nvim_exec2("syntime report", { output = true }).output
  vim.cmd "syntime off"
  vim.fn.assert_notmatch("texDelimRegression", report)

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "(a % )" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local matching = delim.get_matching(delim.get_current("delim_math", "both"))
  vim.fn.assert_equal(0, matching.lnum)
  vim.fn.assert_equal({ 1, 0 }, vim.api.nvim_win_get_cursor(0))

  -- Exercise the operator callback that froze the editor, in both directions.
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "(a % )", "b)" })
  vim.cmd "normal gg0tsd"
  vim.fn.assert_equal(
    { [[\left(a % )]], [[b\right)]] },
    vim.api.nvim_buf_get_lines(0, 0, -1, false)
  )
  vim.cmd "normal gg0tsD"
  vim.fn.assert_equal(
    { "(a % )", "b)" },
    vim.api.nvim_buf_get_lines(0, 0, -1, false)
  )
end, debug.traceback)
if not ok then
  vim.fn.assert_report(message)
end
EOF

call v:lua.require('vimtex.test').finished()
