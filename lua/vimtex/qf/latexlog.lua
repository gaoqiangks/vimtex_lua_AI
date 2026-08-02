local M = { name = "LaTeX logfile" }
local paths = require "vimtex.paths"

local errorformat = {
  "%-P**%f",
  '%-P**"%f"',
  "%+E! Emergency stop.",
  "%E! LaTeX %trror: %m",
  "%E!pdfTeX error: %m",
  "%E%f:%l:  ==> %m",
  "%E%f:%l: %m",
  "%+ERunaway argument?",
  "%-G{/%m",
  "%+C{%m",
  "%C! %m",
  "%Z<argument> %m",
  "%Cl.%l %m",
  "%+WLaTeX Font Warning: %.%#line %l%.%#",
  "%+WLaTeX Font Warning: %m",
  "%-C(Font) %#%m on input line %l%.",
  "%-C(Font)%m",
  "%+WLaTeX %.%#Warning: %.%#line %l%.%#",
  "%+WLaTeX %.%#Warning: %m",
  "%-C               %m on input line %l%.",
  "%+WOverfull %\\%\\hbox%.%# at lines %l--%*\\d",
  "%+WOverfull %\\%\\hbox%.%# at line %l",
  "%+WOverfull %\\%\\vbox%.%# at line %l",
  "%+WOverfull %\\%\\vbox%.%# %m",
  "%+WUnderfull %\\%\\hbox%.%# at lines %l--%*\\d",
  "%+WUnderfull %\\%\\vbox%.%# at line %l",
  "%+WMissing character: %m",
  "%+WPackage natbib Warning: %m on input line %l.",
  "%+WPackage biblatex Warning: %m",
  "%-C(biblatex)%.%#in t%.%#",
  "%-C(biblatex)%.%#Please v%.%#",
  "%-C(biblatex)%.%#LaTeX a%.%#",
  "%-C(biblatex)%m",
  "%+WPackage babel Warning: %m",
  "%-Z(babel)%.%#input line %l.",
  "%-C(babel)%m",
  "%+WPackage hyperref Warning: %m",
  "%-C(hyperref)%m on input line %l.",
  "%-C(hyperref)%m",
  "%+WPackage scrreprt Warning: %m",
  "%-C(scrreprt)%m",
  "%+WPackage fixltx2e Warning: %m",
  "%-C(fixltx2e)%m",
  "%+WPackage titlesec Warning: %m",
  "%-C(titlesec)%m",
  "%+WPackage silence Warning: %m",
  "%-C(silence)%m",
  "%+WPackage %.%# Warning: %m on input line %l.",
  "%+WPackage %.%# Warning: %m",
  "%-Z(%.%#) %m on input line %l.",
  "%-C(%.%#) %m",
  "%+W%.%# Warning: %m on input line %l.",
  "%-G%.%#",
}

local function set_errorformat()
  vim.opt_local.errorformat = errorformat
end

local function fix_hbox(entry, log, root, cache)
  if not entry.text:match "Underfull" and not entry.text:match "Overfull" then
    return false
  end
  local index
  for i, line in ipairs(log) do
    if line == entry.text then
      index = i
      break
    end
  end
  if not index then
    return false
  end
  if cache.index[index] then
    entry.bufnr, entry.filename =
      cache.index[index].bufnr or 0, cache.index[index].filename
    return true
  end
  local file, level = "", 1
  for line_number = index - 1, 2, -1 do
    if cache.paths[line_number] then
      file = cache.paths[line_number]
      break
    end
    level = level
      + require("vimtex.util").count(log[line_number], ")")
      - require("vimtex.util").count(log[line_number], "(")
    if line_number >= index - 1 or level <= 0 then
      file =
        vim.fn.matchstr(log[line_number], [[\v\(\zs\f+\ze\)?\s*%(\[\d+]?)?$]])
      if file ~= "" then
        if not paths.is_abs(file) then
          file = vim.fn.simplify(root .. "/" .. file)
        end
        cache.paths[index] = file
        break
      end
    end
  end
  if file == "" or vim.fn.filereadable(file) == 0 then
    return false
  end
  local buffer = vim.fn.bufnr(file)
  if buffer > 0 then
    entry.bufnr = buffer
    cache.index[index] = { bufnr = buffer }
  else
    entry.bufnr, entry.filename = 0, vim.fn.fnamemodify(file, ":.")
    cache.index[index] = { filename = entry.filename }
  end
  return true
end

local function fix_invalid(entry, root)
  local info = vim.fn.getbufinfo(entry.bufnr)
  local file = info[1] and info[1].name or ""
  if vim.fn.filereadable(file) == 1 then
    return
  end
  file = vim.fn.fnamemodify(
    vim.fn.simplify(root .. "/" .. vim.fn.bufname(entry.bufnr)),
    ":."
  )
  if vim.fn.filereadable(file) == 0 then
    return
  end
  local buffer = vim.fn.bufnr(file)
  if buffer > 0 then
    entry.bufnr = buffer
  else
    entry.bufnr, entry.filename = 0, file
  end
end

function M.fix_paths(main, log_file)
  local quickfix, log = vim.fn.getqflist(), vim.fn.readfile(log_file)
  local root, cache = vim.fn.fnamemodify(main, ":h"), { index = {}, paths = {} }
  for _, entry in ipairs(quickfix) do
    if
      entry.lnum > 0
      and vim.fn.match(entry.text, [[on input line \d\+.$]]) >= 0
    then
      entry.text =
        vim.fn.substitute(entry.text, [[\s*on input line \d\+.$]], "", "")
    end
    if entry.text == "! Emergency stop." then
      entry.text = "Emergency stop (fatal error)!"
    end
    if entry.bufnr == 0 then
      local buffer = vim.fn.bufnr(main)
      if buffer < 0 then
        vim.cmd("badd " .. vim.fn.fnameescape(main))
        buffer = vim.fn.bufnr(main)
      end
      entry.bufnr = buffer
    end
    if #log >= 10000 or not fix_hbox(entry, log, root, cache) then
      fix_invalid(entry, root)
    end
  end
  vim.fn.setqflist(quickfix, "r")
end

function M.addqflist(tex, log)
  if not log or log == "" or vim.fn.filereadable(log) == 0 then
    error "VimTeX: No log file found"
  end
  local saved = vim.opt_local.errorformat:get()
  set_errorformat()
  require("vimtex.qf.util").caddfile(vim.fn.fnameescape(log), saved)
  M.fix_paths(tex, log)
end

return M
