local M = {}

local function os_info()
  local jobs = require "vimtex.jobs"
  local util = require "vimtex.util"
  local os_name = util.get_os()
  if os_name == "linux" then
    local result = vim.fn.executable "lsb_release" == 1
        and jobs.cached("lsb_release -d")[1]:sub(13)
      or jobs.cached("uname -sr")[1]
    return vim.trim(result or "Linux")
  elseif os_name == "mac" then
    if vim.fn.executable "sw_vers" == 1 then
      return table.concat({
        jobs.cached("sw_vers -productName")[1],
        jobs.cached("sw_vers -productVersion")[1],
        "(" .. jobs.cached("sw_vers -buildVersion")[1] .. ")",
      }, " ")
    end
    return "MacOS/i[Pad]OS"
  end
  local data = jobs.cached "systeminfo"
  return "Windows (" .. table.concat(data, " ") .. ")"
end

local function stringify(value, indent, lines, title)
  indent = indent or 0
  lines = lines or {}
  local prefix = string.rep("  ", indent)
  if type(value) ~= "table" then
    lines[#lines + 1] = prefix
      .. (title and title .. ": " or "")
      .. tostring(value)
  elseif vim.islist(value) then
    if title then
      lines[#lines + 1] = prefix .. title .. ":"
    end
    for _, item in ipairs(value) do
      stringify(item, indent + 1, lines)
    end
  else
    if title then
      lines[#lines + 1] = prefix .. title .. ": " .. tostring(value.name or "")
      indent = indent + 1
      prefix = string.rep("  ", indent)
    end
    local keys = vim.tbl_keys(value)
    table.sort(keys)
    for _, key in ipairs(keys) do
      local item = value[key]
      if item ~= vim.NIL and type(item) ~= "function" then
        if type(item) == "table" then
          stringify(item, indent, lines, tostring(key))
        else
          lines[#lines + 1] = prefix .. tostring(key) .. ": " .. tostring(item)
        end
      end
    end
  end
  return lines
end

local function system_info()
  local jobs = require "vimtex.jobs"
  local util = require "vimtex.util"
  local lines = {
    "System info:",
    "  OS: " .. os_info(),
    "  LaTeX version: " .. (vim.fn.executable "latex" == 1 and (jobs.capture(
      "latex --version"
    )[1] or "") or "LATEX WAS NOT FOUND!"),
    "  Neovim version: "
      .. vim.version().major
      .. "."
      .. vim.version().minor
      .. "."
      .. vim.version().patch,
    "  Has clientserver: true",
    "  Servername: "
      .. (vim.v.servername ~= "" and vim.v.servername or "undefined"),
    "  $PATH:",
  }
  local paths = vim.split(
    vim.env.PATH or "",
    util.is_win() and ";" or ":",
    { plain = true }
  )
  table.sort(paths)
  for _, path in ipairs(require("vimtex.util").uniq_unsorted(paths)) do
    lines[#lines + 1] = "    - " .. path
  end
  return lines
end

function M.open(global)
  local previous = vim.api.nvim_get_current_buf()
  vim.cmd "silent keepalt edit VimtexInfo"
  local buffer = vim.api.nvim_get_current_buf()
  vim.bo[buffer].buftype = "nofile"
  vim.bo[buffer].bufhidden = "wipe"
  vim.bo[buffer].swapfile = false
  vim.bo[buffer].modifiable = true
  local lines = system_info()
  lines[#lines + 1] = ""
  if global == true or global == 1 then
    for _, state in ipairs(require("vimtex.state").list_all()) do
      vim.list_extend(lines, stringify(state))
      lines[#lines + 1] = ""
    end
  else
    vim.list_extend(lines, stringify(vim.b.vimtex))
  end
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  for _, key in ipairs { "q", "<Esc>", "<C-6>", "<C-^>", "<C-e>" } do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_buf_is_valid(previous) then
        vim.api.nvim_set_current_buf(previous)
      end
    end, { buffer = true, silent = true })
  end
  vim.cmd [[syntax match VimtexInfoKey /^.\{-}:/ nextgroup=VimtexInfoValue]]
  vim.cmd [[syntax match VimtexInfoValue /.*/ contained]]
  vim.cmd [[syntax match VimtexInfoTitle /\%(VimTeX project:\|System info\)/]]
end

function M.init_buffer()
  vim.api.nvim_buf_create_user_command(0, "VimtexInfo", function(opts)
    M.open(opts.bang)
  end, { bang = true })
  vim.keymap.set("n", "<Plug>(vimtex-info)", function()
    M.open(false)
  end, { buffer = true })
  vim.keymap.set("n", "<Plug>(vimtex-info-full)", function()
    M.open(true)
  end, { buffer = true })
end

return M
