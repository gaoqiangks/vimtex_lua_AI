local M = {}

local syntax = require "vimtex.syntax"
local textwidth

local function indents(number)
  if not vim.bo.expandtab and vim.bo.shiftwidth == vim.bo.tabstop then
    return string.rep("\t", math.floor(number / vim.bo.tabstop))
  end
  return string.rep(" ", number)
end

local function build_lines(first, last)
  if first > last then
    return 0
  end
  local source = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local text_parts = {}
  for _, line in ipairs(source) do
    text_parts[#text_parts + 1] = line:gsub("^%s*", "")
  end
  local text = table.concat(text_parts, " ")
  local trailing = text:match "%s*$" or ""
  local words = vim.split(text, " ", { trimempty = true })
  if #words == 0 then
    return 0
  end
  local prefix = indents(vim.fn.indent(first))
  local current = prefix
  local prefix_width = vim.fn.strdisplaywidth(prefix)
  local current_width = prefix_width
  local replacement = {}
  for _, word in ipairs(words) do
    local word_width = vim.fn.strdisplaywidth(word)
    if word_width + current_width > textwidth then
      replacement[#replacement + 1] = current:gsub("%s$", "")
      current = prefix
      current_width = prefix_width
    end
    current = current .. word .. " "
    current_width = current_width + word_width + 1
  end
  if not current:match "^%s*$" then
    replacement[#replacement + 1] = current:gsub("%s$", "")
  end
  if trailing ~= "" and #replacement > 0 then
    replacement[#replacement] = replacement[#replacement] .. trailing
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, replacement)
  return #replacement - #source
end

local function format_range(first, last)
  local bottom, mark = last, last
  for current = last, first, -1 do
    local line = vim.fn.getline(current)
    if
      syntax.in_mathzone(current, 1)
      and syntax.in_mathzone(current, vim.fn.col { current, "$" })
    then
      mark = current - 1
    elseif line:sub(1, 1) == "%" or line:find "[^\\]%%" then
      if current < mark then
        bottom = bottom + build_lines(current + 1, mark)
      end
      mark = current - 1
    else
      if vim.fn.strdisplaywidth(line) > textwidth then
        bottom = bottom + build_lines(current, mark)
        mark = current - 1
      end
      if vim.fn.match(line, vim.g.vimtex_format_border_end) >= 0 then
        if current < mark then
          bottom = bottom + build_lines(current + 1, mark)
        end
        mark = current
      end
      if vim.fn.match(line, vim.g.vimtex_format_border_begin) >= 0 then
        if current < mark then
          bottom = bottom + build_lines(current, mark)
        end
        mark = current - 1
      end
      if line:match "^%s*$" then
        bottom = bottom + build_lines(current + 1, mark)
        mark = current - 1
      end
    end
  end
  if first <= mark then
    bottom = bottom + build_lines(first, mark)
  end
  return bottom
end

local function compare_lines(new, old)
  local length = math.min(#new, #old)
  for index = 1, length do
    if new[index] ~= old[index] then
      return index - 1
    end
  end
  return length
end

function M.formatexpr()
  if vim.fn.mode():match "[iR]" then
    return -1
  end
  local view = vim.fn.winsaveview()
  local foldenable = vim.wo.foldenable
  vim.wo.foldenable = false
  local top = vim.v.lnum
  local bottom = top + vim.v.count - 1
  local old = vim.api.nvim_buf_get_lines(0, top - 1, bottom, false)
  local tries = 5
  textwidth = vim.bo.textwidth == 0 and 79 or vim.bo.textwidth
  require("vimtex.util").undostore()
  while tries > 0 do
    bottom = format_range(top, bottom)
    if top < bottom then
      pcall(vim.cmd, ("silent normal! %dG=%dG"):format(top + 1, bottom))
    end
    local new = vim.api.nvim_buf_get_lines(0, top - 1, bottom, false)
    local offset = compare_lines(new, old)
    top = top + offset
    if top > bottom then
      break
    end
    old = vim.list_slice(new, offset + 1)
    tries = tries - 1
  end
  vim.wo.foldenable = foldenable
  vim.fn.winrestview(view)
  vim.cmd(("normal! %dG^"):format(bottom))
  if tries == 0 then
    pcall(vim.cmd, "silent undo")
    require("vimtex.log").warning "Formatting of selected text failed!"
  end
  return 0
end

function M.init_buffer()
  if vim.g.vimtex_format_enabled == 0 then
    return
  end
  vim.bo.formatexpr = "v:lua.require('vimtex.format').formatexpr()"
end

return M
