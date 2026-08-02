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
    local match =
      vim.fn.matchlist(line, [[\\FXRegisterAuthor\s*{\([^}]*\)}\s*{\([^}]*\)}]])
    if #match > 0 then
      if match[2] ~= "" then
        commands[#commands + 1] = match[2]
      end
      if match[3] ~= "" then
        environments[#environments + 1] = match[3]
      end
    end
  end

  return {
    cmd = util.uniq_unsorted(commands),
    env = util.uniq_unsorted(environments),
  }
end

return M
