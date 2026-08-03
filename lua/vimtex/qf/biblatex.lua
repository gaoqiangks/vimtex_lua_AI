local M = {}
local util = require "vimtex.util"

local errorformat = {
  "%+E%.%#> ERROR%m",
  "%+W%.%#> WARN - Duplicate entry%m",
  "%+W%.%#> WARN - The entry%.%#cannot be encoded%m",
  "%+I%.%#> INFO - Found BibTeX data source %f",
  "%-G%.%#",
}

local function database_files(state)
  local files = {}
  for _, line in
    ipairs(require("vimtex.parser").preamble(state.tex, { root = state.root }))
  do
    if line:match [[\addbibresource]] then
      local file = vim.fn.matchstr(line, [[{\zs.*\ze}]])
      if vim.fn.filereadable(file) == 1 then
        table.insert(files, file)
      elseif vim.fn.filereadable(vim.fn.expand(file)) == 1 then
        table.insert(files, vim.fn.expand(file))
      else
        local candidates = require("vimtex.kpsewhich").run(file)
        if #candidates == 1 then
          table.insert(files, candidates[1])
        end
      end
    end
  end
  return files
end

local function key_line(key, filename)
  if
    vim.fn.filereadable(filename) == 0 or vim.fn.getfsize(filename) > 200000
  then
    return 0
  end
  local result = 0
  for line_number, line in ipairs(util.readfile(filename)) do
    if vim.fn.match(line, [[^\s*@\w*{\s*\V]] .. key) >= 0 then
      result = line_number
    end
  end
  return result
end

local function key_position(key, files)
  for _, file in ipairs(files) do
    local line = key_line(key, file)
    if line > 0 then
      return file, line
    end
  end
end

local function filename(name, context)
  if vim.fn.filereadable(name) == 0 then
    for _, root in ipairs { context.root, context.state.root } do
      local candidate =
        vim.fn.fnamemodify(vim.fn.simplify(root .. "/" .. name), ":.")
      if vim.fn.filereadable(candidate) == 1 then
        return candidate
      end
    end
  end
  return context.bibfile or ""
end

local function entry_key(name, line, files)
  for _, file in ipairs(files) do
    if vim.fn.fnamemodify(file, ":t") == name then
      local latest = ""
      for _, text in
        ipairs(vim.list_slice(util.readfile(file), 1, tonumber(line)))
      do
        if text:match "^@" then
          latest = text
        end
      end
      if latest ~= "" then
        return vim.fn.matchstr(latest, [[{\v\zs.{-}\ze(,|$)]])
      end
    end
  end
  return ""
end

local function fix(entry, context)
  if entry.text:match "INFO %- Found BibTeX data source" then
    entry._remove = true
    context.bibfile =
      vim.fn.matchstr(entry.text, [[BibTeX data source '\zs.*\ze'$]])
    return
  end
  if entry.text:match "ERROR %- BibTeX subsystem.*expected end of entry" then
    local matches =
      vim.fn.matchlist(entry.text, [[\v(\S*\.%(bib|utf8)).*line (\d+)]])
    if #matches == 0 then
      return
    end
    entry.filename, entry.lnum =
      filename(vim.fn.fnamemodify(matches[2], ":t"), context),
      tonumber(matches[4])
    local key = entry.filename ~= ""
        and entry_key(entry.filename, entry.lnum, context.files)
      or ""
    if entry.filename == "" then
      entry.filename = nil
    end
    entry.text = key ~= ""
        and ('biblatex: Error parsing entry with key "%s"'):format(key)
      or "biblatex: Error parsing entry ("
        .. vim.fn.matchstr(entry.text, [[\vsyntax error: \zs.*\ze \(skipping]])
        .. ")"
    return
  end
  if entry.text:match "WARN %- Duplicate entry" then
    local matches =
      vim.fn.matchlist(entry.text, [[\v: '(\S*)' in file '(.{-})']])
    local key = matches[2]
    entry.filename = filename(matches[3], context)
    entry.lnum, entry.text =
      key_line(key, entry.filename),
      ('biblatex: Duplicate entry key "%s"'):format(key)
    return
  end
  if entry.text:match "No driver for entry type" then
    local key = vim.fn.matchstr(entry.text, [[entry type '\v\zs.{-}\ze']])
    entry.text = "biblatex: Using fallback driver for '" .. key .. "'"
    local file, line = key_position(key, context.files)
    if file then
      entry.filename, entry.lnum, entry.bufnr =
        filename(file, context), line, nil
    end
    return
  end
  if entry.text:match "The following entry could not be found" then
    local parts = vim.split(entry.text, "%s+")
    local key = parts[#parts]
    entry.text = "biblatex: Entry with key '" .. key .. "' not found"
    for _, parsed in ipairs(require("vimtex.parser").tex(context.state.tex)) do
      if
        vim.fn.match(
          parsed[3],
          vim.g["vimtex#re#not_comment"] .. [[\\\S*\V]] .. key
        ) >= 0
      then
        entry.lnum, entry.filename, entry.bufnr = parsed[2], parsed[1], nil
        break
      end
    end
    return
  end
  if entry.text:match "The entry .* has characters which cannot" then
    local key = vim.fn.matchstr(entry.text, [[The entry '\v\zs.{-}\ze']])
    entry.text = "biblatex: Entry with key '"
      .. key
      .. "' has non-ascii characters"
    local file, line = key_position(key, context.files)
    if file then
      entry.filename, entry.lnum, entry.bufnr =
        filename(file, context), line, nil
    end
  end
end

function M.addqflist(blg)
  if
    (vim.g.vimtex_quickfix_blgparser or {}).disable
    or not blg
    or blg == ""
  then
    return
  end
  local saved = vim.opt_local.errorformat:get()
  vim.opt_local.errorformat = errorformat
  require("vimtex.qf.util").caddfile(vim.fn.fnameescape(blg), saved)
  local state = vim.b.vimtex
  local context = {
    root = vim.fn.fnamemodify(blg, ":h"),
    state = state,
    files = database_files(state),
  }
  local title, result = vim.fn.getqflist { title = 1 }, {}
  for _, entry in ipairs(vim.fn.getqflist()) do
    fix(entry, context)
    if not entry._remove then
      table.insert(result, entry)
    end
    entry._remove = nil
  end
  vim.fn.setqflist(result, "r")
  pcall(vim.fn.setqflist, {}, "r", title)
end

return M
