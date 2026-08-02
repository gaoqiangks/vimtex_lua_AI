local bib = require "vimtex.bib"
local parser = require "vimtex.parser.bib"
local paths = require "vimtex.paths"
local pos = require "vimtex.pos"

local M = {}

function M.get_key(command, current_word)
  command = command or require("vimtex.cmd").get_current()
  if
    type(command) ~= "table"
    or not command.name
    or vim.fn.match(command.name:sub(2), vim.g["vimtex#re#cite_cmd"]) < 0
    or #command.args < 1
    or #command.args > 2
  then
    return ""
  end

  current_word = current_word or vim.fn.expand "<cword>"
  local texts = vim.tbl_map(function(argument)
    return argument.text
  end, command.args)
  local cites = vim.split(table.concat(texts, ","), ",%s*")
  return vim.list_contains(cites, current_word) and current_word or cites[1]
end

function M.get_entry(key)
  key = key or M.get_key()
  if key == "" then
    return {}
  end

  paths.pushd(vim.b.vimtex.root)
  local entries = {}
  for _, file in ipairs(bib.files()) do
    vim.list_extend(entries, parser.parse(file))
  end
  paths.popd()

  for _, entry in ipairs(entries) do
    if entry.key == key then
      return entry
    end
  end
  return {}
end

function M.get_key_at(line, column)
  local saved = pos.get_cursor()
  pos.set_cursor(line, column)
  local key = M.get_key()
  pos.set_cursor(saved)
  return key
end

return M
