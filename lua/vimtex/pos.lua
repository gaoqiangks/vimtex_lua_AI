local M = {}

local function parse(...)
  local args = { ... }
  if #args > 1 then
    return parse(args)
  end
  if #args == 0 then
    return nil, nil
  end

  local value = args[1]
  if type(value) == "table" and value.lnum ~= nil then
    return value.lnum, value.cnum
  end
  if #value == 2 then
    return value[1], value[2]
  end
  return value[2], value[3]
end

function M.set_cursor(...)
  local line, column = parse(...)
  vim.fn.cursor(line, column)
end

function M.set_cursor_args(args)
  M.set_cursor(unpack(args))
end

function M.get_cursor()
  return vim.fn.getcurpos()
end

function M.get_cursor_line()
  return M.get_cursor()[2]
end

function M.val(...)
  local line, column = parse(...)
  return 100000 * line + math.min(column, 90000)
end

function M.next(...)
  local line, column = parse(...)
  if column < #vim.fn.getline(line) then
    return { 0, line, column + 1, 0 }
  end
  return { 0, line + 1, 1, 0 }
end

function M.prev(...)
  local line, column = parse(...)
  if column > 1 then
    return { 0, line, column - 1, 0 }
  end
  return { 0, math.max(line - 1, 1), #vim.fn.getline(line - 1), 0 }
end

function M.larger(first, second)
  return M.val(first) > M.val(second)
end

function M.equal(first, second)
  local first_line, first_column = parse(first)
  local second_line, second_column = parse(second)
  return first_line == second_line and first_column == second_column
end

function M.smaller(first, second)
  return M.val(first) < M.val(second)
end

return M
