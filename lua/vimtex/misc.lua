local M = {}

local jobs = require "vimtex.jobs"
local log = require "vimtex.log"
local parser = require "vimtex.parser"
local util = require "vimtex.util"

function M.get_graphicspath(filename)
  local state = vim.b.vimtex
  local roots = state.graphicspath or {}
  for index = 1, #roots + 1 do
    local root = roots[index] or "."
    local candidate =
      vim.fn.simplify(state.root .. "/" .. root .. "/" .. filename)
    for _, suffix in ipairs { "", ".jpg", ".png", ".pdf" } do
      if vim.fn.filereadable(candidate .. suffix) == 1 then
        return candidate .. suffix
      end
    end
  end
  return filename
end

function M.wordcount(opts)
  opts = opts or {}
  local range = opts.range or { 1, vim.fn.line "$" }
  local state = vim.b.vimtex
  local file = range[1] == 1 and range[2] == vim.fn.line "$" and state
    or parser.selection_to_texfile { range = range }
  local command = "texcount -nosub -sum "
    .. ((opts.count_letters == true or opts.count_letters == 1) and "-letter " or "")
    .. ((opts.detailed == true or opts.detailed == 1) and "-inc " or "-q -1 -merge ")
    .. (vim.g.vimtex_texcount_custom_arg or "")
    .. " "
    .. util.shellescape(file.base)
  local lines = jobs.capture(command, { cwd = file.root })
  if file.base ~= state.base then
    vim.fn.delete(file.tex)
  end
  if opts.detailed == true or opts.detailed == 1 then
    return lines
  end
  local result = {}
  for _, line in ipairs(lines) do
    if
      not line:match "ERROR"
      and not line:match "^%s*$"
      and not line:match "^Possible precedence problem"
    then
      result[#result + 1] = line
    end
  end
  return table.concat(result)
end

function M.wordcount_display(opts)
  local output = M.wordcount(opts)
  if opts.detailed ~= true and opts.detailed ~= 1 then
    log.info(
      "Counted "
        .. ((opts.count_letters == true or opts.count_letters == 1) and "letters: " or "words: ")
        .. output
    )
    return
  end
  local old = vim.fn.bufnr "TeXcount"
  if old >= 0 then
    vim.api.nvim_buf_delete(old, { force = true })
  end
  vim.cmd "split TeXcount"
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, output)
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = false
  vim.wo.cursorline = true
  vim.keymap.set(
    "n",
    "q",
    "<Cmd>bwipeout<CR>",
    { buffer = true, silent = true }
  )
  vim.cmd [[syntax match TexcountText /^.*:.*/ contains=TexcountValue]]
  vim.cmd [[syntax match TexcountValue /.*:\zs.*/]]
  vim.cmd "highlight link TexcountText VimtexMsg"
  vim.cmd "highlight link TexcountValue Constant"
end

local reloading = false

function M.reload()
  if reloading then
    return
  end
  reloading = true
  pcall(require("vimtex.compiler").stop_all)
  for name in pairs(package.loaded) do
    if name == "vimtex" or name:match "^vimtex%." then
      package.loaded[name] = nil
    end
  end
  local reload_syntax = vim.b.current_syntax == "tex"
  if reload_syntax then
    vim.b.current_syntax = nil
  end
  vim.b.did_ftplugin = nil
  require("vimtex.ftplugin").setup "tex"
  if reload_syntax then
    vim.cmd "syntax clear"
    vim.cmd "runtime! syntax/tex.lua"
  end
  if vim.b.did_vimtex_indent then
    vim.b.did_indent = nil
    vim.cmd "runtime indent/tex.lua"
  end
  require("vimtex.log").info "The plugin has been reloaded!"
  reloading = false
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexReload", M.reload, {})
  local function count(opts, letters)
    M.wordcount_display {
      range = { opts.line1, opts.line2 },
      detailed = opts.bang,
      count_letters = letters,
    }
  end
  vim.api.nvim_buf_create_user_command(0, "VimtexCountWords", function(opts)
    count(opts, false)
  end, { bang = true, range = "%" })
  vim.api.nvim_buf_create_user_command(0, "VimtexCountLetters", function(opts)
    count(opts, true)
  end, { bang = true, range = "%" })
  vim.keymap.set("n", "<Plug>(vimtex-reload)", M.reload, { buffer = true })
end

return M
