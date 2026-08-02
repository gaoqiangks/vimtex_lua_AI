local M = {}

local ui = require "vimtex.ui"
local entries = {}
local verbose = vim.g.vimtex_log_verbose ~= 0
local verbose_old

local highlights =
  { info = "VimtexInfo", warning = "VimtexWarning", error = "VimtexError" }
local levels = { info = 1, warning = 2, error = 3 }

local function stacktrace()
  local result = {}
  for depth = 4, 14 do
    local info = debug.getinfo(depth, "Sln")
    if not info then
      break
    end
    result[#result + 1] = {
      filename = (info.source or ""):gsub("^@", ""),
      ["function"] = info.name or "<anonymous>",
      lnum = info.currentline or 0,
      text = "",
      nr = depth - 4,
    }
  end
  return result
end

local function normalize(...)
  local result = {}
  for _, value in ipairs { ... } do
    if type(value) == "string" then
      result[#result + 1] = value
    elseif type(value) == "table" then
      for _, item in ipairs(value) do
        if type(item) == "string" then
          result[#result + 1] = item
        end
      end
    end
  end
  return result
end

local function notify(messages, kind)
  for _, pattern in ipairs(vim.g.vimtex_log_ignore or {}) do
    if vim.fn.match(table.concat(messages), pattern) >= 0 then
      return
    end
  end
  if #messages == 0 then
    return
  end
  ui.echo { { highlights[kind], "VimTeX:" }, " " .. messages[1] }
  for index = 2, #messages do
    ui.echo(messages[index], { indent = 8 })
  end
end

local function add(kind, ...)
  local messages = normalize(...)
  entries[#entries + 1] = {
    type = kind,
    time = os.date "%H:%M:%S",
    msg = messages,
    callstack = stacktrace(),
  }
  if verbose then
    notify(messages, kind)
  end
end

function M.info(...)
  add("info", ...)
end

function M.warning(...)
  add("warning", ...)
end

function M.error(...)
  add("error", ...)
end

function M.get()
  return entries
end

function M.toggle_verbose()
  verbose = not verbose
end

function M.set_silent()
  if verbose_old == nil then
    verbose_old = verbose
  end
  verbose = false
end

function M.set_silent_restore()
  if verbose_old ~= nil then
    verbose = verbose_old
  end
end

function M.open()
  vim.cmd "botright new"
  local buffer = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buffer, "VimtexMessageLog")
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = true
  local lines_out = {}
  for _, entry in ipairs(entries) do
    lines_out[#lines_out + 1] = ("%s: %s"):format(entry.time, entry.type)
    for _, frame in ipairs(entry.callstack) do
      lines_out[#lines_out + 1] = ("  #%d %s:%d"):format(
        frame.nr,
        frame.filename,
        frame.lnum
      )
      lines_out[#lines_out + 1] = "  In " .. frame["function"]
    end
    for _, message in ipairs(entry.msg) do
      lines_out[#lines_out + 1] = "  " .. message
    end
    lines_out[#lines_out + 1] = ""
  end
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines_out)
  vim.bo[buffer].modifiable = false
  vim.cmd [[syntax match VimtexInfoKey /^\S*:/ nextgroup=VimtexInfoValue]]
  vim.cmd [[syntax match VimtexInfoKey /^  #\d\+/ nextgroup=VimtexInfoValue]]
  vim.cmd [[syntax match VimtexInfoKey /^  In/ nextgroup=VimtexInfoValue]]
  vim.cmd [[syntax match VimtexInfoValue /.*/ contained]]
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexLog", M.open, { bang = true })
  vim.keymap.set("n", "<Plug>(vimtex-log)", M.open, { buffer = true })
end

return M
