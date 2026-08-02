local M = {}

local colors = {
  content = "\27[37m",
  include = "\27[34m",
  label = "\27[32m",
  todo = "\27[31m",
}

local function format_number(number)
  if type(number) ~= "table" or number.chapter == nil then
    return ""
  end
  local result = {}
  for _, key in ipairs {
    "chapter",
    "section",
    "subsection",
    "subsubsection",
    "subsubsubsection",
  } do
    if tostring(number[key]) ~= "0" then
      result[#result + 1] = tostring(number[key])
    end
  end
  if tostring(number.appendix) ~= "0" and result[1] then
    result[1] = string.char(tonumber(result[1]) + 64)
  end
  return table.concat(result, ".")
end

local function colorize(entry)
  local title = string.format("%-65s", entry.title)
  if vim.fn.has "win32" == 1 then
    return title
  end
  return (colors[entry.type] or "") .. title .. "\27[0m"
end

local function candidates(filter)
  local entries = require("vimtex.parser").toc()
  local result = {}
  for _, entry in ipairs(entries) do
    if filter:find(entry.type:sub(1, 1), 1, true) then
      result[#result + 1] = string.format(
        "%d#####%s#####%s %s",
        entry.line or 0,
        entry.file,
        colorize(entry),
        format_number(entry.number)
      )
    end
  end
  return result
end

function M.open_selection(selection)
  local parts = vim.split(selection, "#####", { plain = true })
  local line, file = tonumber(parts[1]), parts[2]
  if vim.fn.expand "%:p" == file then
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  else
    vim.api.nvim_cmd({ cmd = "edit", args = { file } }, {})
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  end
end

function M.run(filter, options)
  filter = filter or "ctli"
  local opts = vim.tbl_extend("force", {
    source = candidates(filter),
    sink = M.open_selection,
    options = '--ansi --with-nth 3.. --delimiter "#####"',
  }, options or {})
  vim.fn["fzf#run"](opts)
end

return M
