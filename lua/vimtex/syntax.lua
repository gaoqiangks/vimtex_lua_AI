local M = {}

local ignored_math_groups = { "texMathText", "texMathTag", "texRefArg" }
local group_names = {}

function M.stack(line, column)
  if not line or not column then
    local cursor = vim.api.nvim_win_get_cursor(0)
    line = line or cursor[1]
    column = column or cursor[2] + 1
  end
  if vim.fn.mode() == "i" then
    column = column - 1
  end
  line, column = math.max(line, 1), math.max(column, 1)

  local result = {}
  for _, id in ipairs(vim.fn.synstack(line, column)) do
    local name = group_names[id]
    if not name then
      name = vim.fn.synIDattr(id, "name")
      group_names[id] = name
    end
    result[#result + 1] = name
  end
  return result
end

function M.in_group(name, line, column)
  local literal = name:match "^[%w_]+$" ~= nil
  local ignore_case = literal and vim.o.ignorecase
  local prefix = ignore_case and name:lower() or name
  for _, group in ipairs(M.stack(line, column)) do
    if
      (
        literal
        and (
            ignore_case and group:sub(1, #name):lower() or group:sub(1, #name)
          )
          == prefix
      ) or (not literal and vim.fn.match(group, "^" .. name) >= 0)
    then
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
  local ignore_case = vim.o.ignorecase
  for index = #groups, 1, -1 do
    local group = groups[index]
    if group:match "^texMathZone" then
      return true
    end
    for index, pattern in ipairs(ignored_math_groups) do
      if
        (
          index <= 3
          and (
            group:sub(1, #pattern) == pattern
            or (
              ignore_case
              and group:sub(1, #pattern):lower() == pattern:lower()
            )
          )
        )
        or (index > 3 and vim.fn.match(group, "^" .. pattern) >= 0)
      then
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
