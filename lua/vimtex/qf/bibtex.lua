local M = {}
local util = require "vimtex.util"

local errorformat = {
  "%+EName%.%#has a comma at the end%.%#",
  "%+EI found %.%#---while reading file %f",
  "%+WWarning--empty %.%# in %.%m",
  "%+WWarning--entry type for%m",
  "%-Cwhile executing---line %l of file %f",
  "%-C--line %l of file %f",
  "%-G%.%#",
}

local function database_files(file, out_dir)
  local result = {}
  for _, line in ipairs(util.readfile(file)) do
    if line:match "Database file #%d:" then
      local name = vim.fn.matchstr(line, [[: \zs.*]])
      if vim.fn.filereadable(name) == 1 then
        table.insert(result, name)
      elseif vim.fn.filereadable(out_dir .. name) == 1 then
        table.insert(result, out_dir .. name)
      end
    end
  end
  return result
end

local function key_location(key, context)
  context.lines = context.lines or {}
  for _, file in ipairs(context.files) do
    local lines = context.lines[file]
    if not lines then
      lines = util.readfile(file)
      context.lines[file] = lines
    end
    for line_number, line in ipairs(lines) do
      if vim.fn.match(line, [[^\s*@\w*{\s*\V]] .. key) >= 0 then
        return file, line_number
      end
    end
  end
end

local function fix_entry(entry, context)
  if vim.fn.match(entry.text, [[---line \d\+ of file]]) >= 0 then
    entry.text = vim.split(entry.text, "---", { plain = true })[1]
    return
  end
  local matches =
    vim.fn.matchlist(entry.text, [[\vWarning--empty (.*) in ([^ ;]*)(.*)]])
  if #matches > 0 then
    local kind, key = matches[2], matches[3]
    local more = vim.fn.matchstr(matches[4], [[; \zs.*]])
    entry.bufnr = nil
    entry.text = more == "" and ('Missing "%s" in "%s"'):format(kind, key)
      or ('Missing "%s" in "%s" (%s)'):format(kind, key, more)
    local file, line = key_location(key, context)
    if file then
      entry.filename, entry.lnum = file, line
    end
    return
  end
  matches = vim.fn.matchlist(entry.text, [[\vWarning--entry type for "(\w+)"]])
  if #matches > 0 then
    local key = matches[2]
    entry.bufnr = nil
    entry.text = ('Entry type for "%s" isn\'t style-file defined'):format(key)
    local file, line = key_location(key, context)
    if file then
      entry.filename, entry.lnum = file, line
    end
    return
  end
  if entry.text:match [[I found no \bibstyle]] then
    entry.text =
      [[BibTeX found no \bibstyle command (missing \bibliographystyle?)]]
    entry.filename, entry.bufnr = context.tex, nil
    for _, parsed in ipairs(require("vimtex.parser").tex(context.tex)) do
      if
        vim.fn.match(
          parsed[3],
          vim.g["vimtex#re#not_comment"] .. [[\\bibliography]]
        ) >= 0
      then
        entry.filename, entry.lnum = parsed[1], parsed[2]
        break
      end
    end
    return
  end
  local filename = entry.filename
    or (entry.bufnr and vim.fn.bufname(entry.bufnr))
    or ""
  if filename:match "%.bst$" and vim.fn.filereadable(filename) == 0 then
    local found = require("vimtex.kpsewhich").find(filename)
    if vim.fn.filereadable(found) == 1 then
      entry.filename, entry.bufnr = found, nil
    end
  end
end

function M.addqflist(blg, out_dir, tex)
  if (vim.g.vimtex_quickfix_blgparser or {}).disable then
    return
  end
  if not blg or blg == "" or vim.fn.filereadable(blg) == 0 then
    return
  end
  local saved = vim.opt_local.errorformat:get()
  vim.opt_local.errorformat = errorformat
  require("vimtex.qf.util").caddfile(vim.fn.fnameescape(blg), saved)
  local title = vim.fn.getqflist { title = 1 }
  local context = { files = database_files(blg, out_dir or ""), tex = tex }
  local list = vim.fn.getqflist()
  for _, entry in ipairs(list) do
    fix_entry(entry, context)
  end
  vim.fn.setqflist(list, "r")
  pcall(vim.fn.setqflist, {}, "r", title)
end

return M
