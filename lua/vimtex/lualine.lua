local M = {}

local states = {}
local spinner_frames =
  { "⠋", "⠙", "⠸", "⠴", "⠦", "⠧", "⠇", "⠋" }
local timer
local initialized = false

local function enabled()
  return vim.g.vimtex_lualine_enabled ~= 0
end

local function options()
  return vim.g.vimtex_lualine or {}
end

local function spinner_interval()
  return math.max(50, tonumber(options().spinner_interval) or 200)
end

local function project(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local id = vim.b[bufnr].vimtex_id
  local state = type(id) == "number" and require("vimtex.state").get(id) or nil
  return state and state.tex ~= "" and state.tex or nil
end

local function refresh()
  vim.cmd "redrawstatus"
  local lualine = package.loaded.lualine
  if lualine and type(lualine.refresh) == "function" then
    pcall(lualine.refresh, { place = { "statusline" } })
  end
end

local function stop_timer_if_idle()
  for _, state in pairs(states) do
    if state.status == "compiling" then
      return
    end
  end
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

local function start_timer()
  if timer then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(0, spinner_interval(), vim.schedule_wrap(refresh))
end

local function count_quickfix()
  local errors, warnings = 0, 0
  for _, entry in ipairs(vim.fn.getqflist()) do
    if entry.type == "E" then
      errors = errors + 1
    elseif entry.type == "W" then
      warnings = warnings + 1
    end
  end
  return errors, warnings
end

local function update(status)
  if not enabled() then
    return
  end
  local key = project()
  if not key then
    return
  end
  local state = states[key] or { errors = 0, warnings = 0 }
  state.status = status
  state.updated = vim.uv.hrtime()
  if status == "success" or status == "failed" then
    state.errors, state.warnings = count_quickfix()
  end
  states[key] = state
  if status == "compiling" then
    start_timer()
  else
    stop_timer_if_idle()
    refresh()
  end
end

local function current_state(bufnr)
  local key = project(bufnr)
  return key and states[key] or nil
end

function M.status(bufnr)
  if not enabled() then
    return ""
  end
  local state = current_state(bufnr)
  if not state then
    return ""
  end
  local opts = options()
  if state.status == "compiling" then
    local interval = spinner_interval()
    local index = math.floor(vim.uv.hrtime() / 1e6 / interval) % #spinner_frames
      + 1
    return (opts.compiling_icon or spinner_frames[index]) .. " Compiling"
  end

  local icon = state.status == "success" and (opts.success_icon or "✓")
    or state.status == "failed" and (opts.failure_icon or "✗")
    or (opts.stopped_icon or "■")
  local label = state.status == "success" and "Compiled"
    or state.status == "failed" and "Failed"
    or "Stopped"
  if opts.show_counts == false then
    return icon .. " " .. label
  end
  return ("%s %s E:%d W:%d"):format(icon, label, state.errors, state.warnings)
end

function M.color(bufnr)
  local state = current_state(bufnr)
  if not state then
    return nil
  end
  local colors = options().colors or {}
  if state.status == "compiling" then
    return colors.compiling or { fg = "#e0af68" }
  elseif state.status == "success" then
    return colors.success or { fg = "#9ece6a" }
  elseif state.status == "failed" then
    return colors.failed or { fg = "#f7768e" }
  end
  return colors.stopped or { fg = "#bb9af7" }
end

function M.component()
  return {
    M.status,
    cond = function()
      return M.status() ~= ""
    end,
    color = M.color,
  }
end

function M.setup()
  if initialized or not enabled() then
    return
  end
  initialized = true
  local group = vim.api.nvim_create_augroup("vimtex_lualine", { clear = true })
  for pattern, status in pairs {
    VimtexEventCompiling = "compiling",
    VimtexEventCompileSuccess = "success",
    VimtexEventCompileFailed = "failed",
    VimtexEventCompileStopped = "stopped",
  } do
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = pattern,
      callback = function()
        update(status)
      end,
    })
  end
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventQuit",
    callback = function()
      local key = project()
      if key then
        states[key] = nil
      end
      stop_timer_if_idle()
    end,
  })
end

M._states = states

return M
