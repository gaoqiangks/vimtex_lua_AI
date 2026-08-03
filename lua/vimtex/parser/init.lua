local M = {}

local auxiliary = require "vimtex.parser.auxiliary"
local bib = require "vimtex.parser.bib"
local cache = require "vimtex.cache"
local fls = require "vimtex.parser.fls"
local paths = require "vimtex.paths"
local tex = require "vimtex.parser.tex"
local toc = require "vimtex.parser.toc"
local util = require "vimtex.util"

M.tex = tex.parse
M.preamble = tex.parse_preamble
M.auxiliary = auxiliary.parse
M.fls = fls.parse
M.bib = bib.parse

function M.toc(state)
  state = state or vim.b.vimtex
  local store = cache.open("parser_toc", {
    persistent = false,
    default = { entries = {}, ftime = -1 },
  })
  local current = store:get(state.tex)
  local file_time = state == vim.b.vimtex and vim.fn.eval "b:vimtex.getftime()"
    or vim.fn.getftime(state.tex)
  if file_time > current.ftime then
    current.ftime = file_time
    current.entries = toc.parse(state.tex)
  end
  return vim.deepcopy(current.entries)
end

function M.get_externalfiles()
  local state = vim.b.vimtex
  if type(state) ~= "table" then
    return {}
  end
  local result = {}
  for _, line in ipairs(tex.parse_preamble(state.tex)) do
    if line:find("\\externaldocument", 1, true) then
      local name = line:match "{([^}]*)}" or ""
      result[#result + 1] = {
        tex = name .. ".tex",
        aux = name .. ".aux",
        opt = line:match "%[([^]]*)%]" or "",
      }
    end
  end
  return result
end

function M.selection_to_texfile(opts)
  local state = vim.b.vimtex
  opts = vim.tbl_extend("force", {
    type = "range",
    range = { 0, 0 },
    name = state.name .. "_vimtex_selected",
    template_name = "vimtex-template.tex",
  }, opts or {})
  if opts.type == "visual" then
    opts.range = { vim.fn.line "'<", vim.fn.line "'>" }
  elseif opts.type == "operator" then
    opts.range = { vim.fn.line "'[", vim.fn.line "']" }
  end

  local lines = vim.api.nvim_buf_get_lines(
    0,
    math.max(opts.range[1] - 1, 0),
    opts.range[2],
    false
  )
  local first, last = 1, #lines
  for index, line in ipairs(lines) do
    if line:find "\\begin%s*{document}" then
      first = index + 1
    elseif line:find "\\end%s*{document}" then
      last = index - 1
      break
    end
  end
  if first > #lines or last < 1 then
    return {}
  end
  local selected = vim.list_slice(lines, first, last)
  if table.concat(selected):gsub("%s", "") == "" then
    return {}
  end

  local template = {}
  for _, filename in ipairs {
    vim.fn.expand "%:r" .. "-" .. opts.template_name,
    opts.template_name,
  } do
    local lines, readable = util.readfile(filename)
    if readable then
      template = lines
      break
    end
  end
  if #template > 0 then
    local placeholder = vim.fn.index(template, "%%% VIMTEX PLACEHOLDER") + 1
    local merged = vim.list_slice(template, 1, placeholder - 1)
    vim.list_extend(merged, selected)
    vim.list_extend(merged, vim.list_slice(template, placeholder + 1))
    selected = merged
  else
    selected = vim.list_extend(tex.parse_preamble(state.tex), selected)
    selected[#selected + 1] = [[\end{document}]]
  end

  local out_dir = state.compiler.out_dir
  if out_dir == "" then
    out_dir = state.root
  elseif not paths.is_abs(out_dir) then
    out_dir = state.root .. "/" .. out_dir
  end
  local file = {
    root = out_dir,
    name = opts.name,
    base = opts.name .. ".tex",
    tex = out_dir .. "/" .. opts.name .. ".tex",
    pdf = out_dir .. "/" .. opts.name .. ".pdf",
  }
  vim.fn.writefile(selected, file.tex)
  return file
end

return M
