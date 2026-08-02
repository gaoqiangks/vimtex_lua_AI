local M = {}

local visited = { time = 0, list = {} }
local command_pattern =
  [[\v\s*\\%(documentclass|LoadClass|usepackage|RequirePackage|PassOptionsToClass|PassOptionsToPackage)]]

local function timeout()
  if os.time() - visited.time > 1 then
    visited.time = os.time()
    visited.list = { vim.fn.expand "%:p" }
  end
end

local function check(file)
  local absolute = vim.fn.fnamemodify(file, ":p")
  if not vim.list_contains(visited.list, absolute) then
    visited.list[#visited.list + 1] = absolute
    return file
  end
  return ""
end

local function parse_input(filename, kind)
  local position = vim.fn.searchpos(
    vim.g["vimtex#re#" .. kind .. "_input"],
    "bcn",
    vim.fn.line "."
  )
  if position[1] == 0 then
    return filename
  end
  local command = require("vimtex.cmd").get_at(position[1], position[2])
  if vim.fn.empty(command) == 1 then
    return filename
  end
  local parts = {}
  for _, argument in ipairs(command.args or {}) do
    parts[#parts + 1] = argument.text or ""
  end
  local file =
    table.concat(parts):gsub('^%s*"', ""):gsub('"%s*$', ""):gsub("\\space", "")
  if file:sub(-3) ~= kind then
    file = file .. "." .. kind
  end
  return file
end

local function parse_package(filename)
  local position = vim.fn.searchpos(command_pattern, "bcn", vim.fn.line ".")
  if position[1] == 0 then
    return filename
  end
  local command = require("vimtex.cmd").get_at(position[1], position[2])
  if vim.fn.empty(command) == 1 then
    return filename
  end
  local index = command.name:find("PassOptionsTo", 1, true) and 2 or 1
  return vim.trim((command.args[index] or {}).text or filename)
end

local function search_texinputs(filename)
  for _, suffix in
    ipairs(
      vim.list_extend(
        { "" },
        vim.split(vim.bo.suffixesadd, ",", { trimempty = true })
      )
    )
  do
    local candidates = vim.fn.glob(
      vim.b.vimtex.root .. "/**/" .. vim.fn.fnameescape(filename) .. suffix,
      false,
      true
    )
    if #candidates > 0 then
      return candidates[1]
    end
  end
  return ""
end

local function search_kpsewhich(filename)
  local files = vim.fn.split(filename, [[\s*,\s*]])
  local current = vim.fn.expand "<cword>"
  local index = vim.fn.index(files, current)
  if index >= 0 then
    table.remove(files, index + 1)
    table.insert(files, 1, current)
  end
  local candidates = {}
  for _, file in ipairs(files) do
    if vim.fn.fnamemodify(file, ":e") ~= "" then
      candidates[#candidates + 1] = file
    else
      for _, suffix in
        ipairs(vim.split(vim.bo.suffixesadd, ",", { trimempty = true }))
      do
        candidates[#candidates + 1] = file .. suffix
      end
    end
  end
  for _, file in ipairs(candidates) do
    local result = require("vimtex.kpsewhich").run(vim.fn.fnameescape(file))[1]
      or ""
    if result ~= "" and vim.fn.filereadable(result) == 1 then
      return result
    end
  end
  return ""
end

function M.expr()
  timeout()
  local filename = vim.trim(vim.v.fname)
  if vim.fn.filereadable(filename) == 1 then
    return check(filename)
  end
  local file = parse_input(filename, "tex")
  for _, candidate in ipairs { file, file .. ".tex" } do
    if vim.fn.filereadable(candidate) == 1 then
      return check(candidate)
    end
  end
  local bibliography = parse_input(filename, "bib")
  if vim.fn.filereadable(bibliography) == 1 then
    return check(bibliography)
  end
  local candidate = search_texinputs(filename)
  if candidate ~= "" then
    return check(candidate)
  end
  if vim.g.vimtex_include_search_enabled ~= 0 then
    candidate = search_kpsewhich(parse_package(filename))
    if candidate ~= "" then
      return check(candidate)
    end
  end
  return check(filename)
end

return M
