local M = {}

local ignored_math_groups = { "texMathText", "texMathTag", "texRefArg" }

function M.stack(line, column)
  line = line or vim.fn.line "."
  column = column or vim.fn.col "."
  if vim.fn.mode() == "i" then
    column = column - 1
  end
  line, column = math.max(line, 1), math.max(column, 1)

  return vim.tbl_map(function(id)
    return vim.fn.synIDattr(id, "name")
  end, vim.fn.synstack(line, column))
end

function M.in_group(name, line, column)
  for _, group in ipairs(M.stack(line, column)) do
    if vim.fn.match(group, "^" .. name) >= 0 then
      return true
    end
  end
  return false
end

function M.in_comment(line, column)
  return M.in_group("texComment", line, column)
end

function M.in_mathzone(line, column)
  local groups = M.stack(line, column)
  for index = #groups, 1, -1 do
    local group = groups[index]
    if group:match "^texMathZone" then
      return true
    end
    for _, pattern in ipairs(ignored_math_groups) do
      if vim.fn.match(group, "^" .. pattern) >= 0 then
        return false
      end
    end
  end
  return false
end

function M.add_to_mathzone_ignore(pattern)
  ignored_math_groups[#ignored_math_groups + 1] = pattern
end

_G.vimtex_syntax_stack = M.stack
_G.vimtex_syntax_in = M.in_group
_G.vimtex_syntax_in_comment = M.in_comment
_G.vimtex_syntax_in_mathzone = M.in_mathzone
_G.vimtex_syntax_add_to_mathzone_ignore = M.add_to_mathzone_ignore

return M
