local M = {}
local util = require "vimtex.util"
local complete_dir = vim.fn.fnamemodify(
  debug.getinfo(1, "S").source:sub(2),
  ":h:h:h:h"
) .. "/autoload/vimtex/complete/"
local complete_cache = {}

local function read_complete(package)
  local cached = complete_cache[package]
  if cached then
    return cached
  end
  local lines = util.readfile(complete_dir .. package)
  complete_cache[package] = lines
  return lines
end

local function command_context(name)
  local state = vim.b.vimtex or {}
  local packages = { "default", "class-" .. (state.documentclass or "") }
  vim.list_extend(packages, vim.tbl_keys(state.packages or {}))
  local readable, included = {}, {}
  for _, package in ipairs(packages) do
    if vim.fn.filereadable(complete_dir .. package) == 1 then
      readable[#readable + 1] = package
      included[package] = true
    end
  end
  packages = readable
  local queue = vim.list_slice(packages)
  local index = 1
  while index <= #queue do
    local package = queue[index]
    index = index + 1
    for _, line in ipairs(read_complete(package)) do
      local include = line:match "^#%s*include:%s*(.-)%s*$"
      if
        include
        and vim.fn.filereadable(complete_dir .. include) == 1
        and not included[include]
      then
        included[include] = true
        table.insert(packages, include)
        table.insert(queue, include)
      end
    end
  end
  local candidates = {}
  for _, package in ipairs(packages) do
    local found = false
    for _, command in ipairs(read_complete(package)) do
      if command == name then
        found = true
        break
      end
    end
    if found then
      if package == "default" then
        vim.list_extend(candidates, { "latex2e", "lshort" })
      else
        table.insert(candidates, package:gsub("^class%-", ""))
      end
    end
  end
  return { type = "command", name = name, candidates = candidates }
end

local function cursor_context()
  local command = require("vimtex.cmd").get_current()
  if vim.tbl_isempty(command) then
    return nil
  end
  local ok, context = pcall(function()
    if command.name == "\\usepackage" or command.name == "\\RequirePackage" then
      local candidates = vim.split(
        command.args[1].text:gsub("%%.-\n", ""):gsub("%s", ""),
        ",",
        { trimempty = true }
      )
      local result = { type = "usepackage", candidates = candidates }
      local word = vim.fn.expand "<cword>"
      if #candidates > 1 and vim.tbl_contains(candidates, word) then
        result.selected = word
      end
      return result
    elseif command.name == "\\documentclass" then
      return { type = "documentclass", candidates = { command.args[1].text } }
    elseif command.name == "\\begin" or command.name == "\\end" then
      return command_context("\\begin{" .. command.args[1].text .. "}")
    elseif command.name == "\\usetikzlibrary" then
      local candidates = { "tikz" }
      for _, name in
        ipairs(
          vim.split(
            command.args[1].text:gsub("%s", ""),
            ",",
            { trimempty = true }
          )
        )
      do
        local path =
          require("vimtex.kpsewhich").find("tikzlibrary" .. name .. ".code.tex")
        if path ~= "" and not path:match "pgf.*tikz.libraries" then
          table.insert(candidates, name)
        end
      end
      local result = { type = "tikzlibrary", candidates = candidates }
      local word = vim.fn.expand "<cword>"
      if #candidates > 1 and vim.tbl_contains(candidates, word) then
        result.selected = word
      end
      return result
    end
    return command_context(command.name:sub(2))
  end)
  if not ok then
    require("vimtex.log").warning "Could not parse documentation context"
    return nil
  end
  return context
end

local function remove_invalid(context)
  if context.type == "tikzlibrary" then
    return
  end
  local invalid = {}
  for _, package in ipairs(context.candidates) do
    if
      package ~= "latex2e"
      and package ~= "lshort"
      and require("vimtex.kpsewhich").find(package .. ".sty") == ""
      and require("vimtex.kpsewhich").find(package .. ".cls") == ""
    then
      table.insert(invalid, package)
    end
  end
  if #invalid > 0 then
    require("vimtex.log").warning(
      #invalid == 1 and ("Package not recognized: " .. invalid[1])
        or vim.list_extend(
          { "Packages not recognized:" },
          vim.tbl_map(function(x)
            return "- " .. x
          end, invalid)
        )
    )
  end
  context.candidates = vim.tbl_filter(function(x)
    return not vim.tbl_contains(invalid, x)
  end, context.candidates)
  if
    context.selected
    and not vim.tbl_contains(context.candidates, context.selected)
  then
    context.selected = nil
  end
end

function M.get_context(word)
  local context = word
      and word ~= ""
      and { type = "word", candidates = { word } }
    or cursor_context()
  if not context then
    return {}
  end
  remove_invalid(context)
  return context
end

function M.make_selection(context)
  if context.selected ~= nil then
    return
  end
  if #context.candidates == 0 then
    context.selected = ""
    return
  end
  if #context.candidates == 1 then
    context.selected = context.candidates[1]
    if
      vim.g.vimtex_doc_confirm_single == 1
      and not require("vimtex.ui").confirm(
        "Open documentation for "
          .. context.type
          .. ": "
          .. context.selected
          .. "?"
      )
    then
      context.selected = ""
    end
    return
  end
  context.selected = require("vimtex.ui").select(
    context.candidates,
    { prompt = "Multiple candidates detected, please select one:" }
  ) or ""
end

function M.texdoc(context)
  M.make_selection(context)
  if context.selected == "" then
    return false
  end
  require("vimtex.jobs").run("texdoc --nointeract -l " .. context.selected)
  if vim.v.shell_error ~= 0 then
    return false
  end
  require("vimtex.jobs").start("texdoc " .. context.selected)
  return true
end

function M.package(word)
  local context = M.get_context(word)
  if vim.tbl_isempty(context) then
    return
  end
  for _, handler in ipairs(vim.g.vimtex_doc_handlers or {}) do
    local handled = handler == "vimtex#doc#handlers#texdoc"
        and M.texdoc(context)
      or vim.fn[handler](context) ~= 0
    if handled then
      return
    end
  end
  M.make_selection(context)
  if context.selected ~= "" then
    require("vimtex.util").www("http://texdoc.org/pkg/" .. context.selected)
  end
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexDocPackage", function(opts)
    M.package(opts.args)
  end, { nargs = "?" })
  vim.keymap.set(
    "n",
    "<plug>(vimtex-doc-package)",
    "<cmd>VimtexDocPackage<cr>",
    { buffer = true }
  )
end

return M
