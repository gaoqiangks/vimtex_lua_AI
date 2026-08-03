local M = {}

local tex = require "vimtex.parser.tex"
local util = require "vimtex.util"

function M.authors()
  local commands = { "fx" }
  local environments = { "anfx" }
  local state = vim.b.vimtex
  if type(state) ~= "table" then
    return { cmd = commands, env = environments }
  end

  for _, line in ipairs(tex.parse_preamble(state.tex, {})) do
    local command, environment =
      line:match "\\FXRegisterAuthor%s*{([^}]*)}%s*{([^}]*)}"
    if command then
      if command ~= "" then
        commands[#commands + 1] = command
      end
      if environment ~= "" then
        environments[#environments + 1] = environment
      end
    end
  end

  return {
    cmd = util.uniq_unsorted(commands),
    env = util.uniq_unsorted(environments),
  }
end

return M
