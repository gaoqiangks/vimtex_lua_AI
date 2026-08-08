local M = {}

local spinner_frames =
  { "⠋", "⠙", "⠸", "⠴", "⠦", "⠧", "⠇", "⠋" }
local backend
local current
local timer
local initialized = false

local function flag(value, default)
  if value == nil then
    return default
  end
  return value ~= false and value ~= 0
end

local function enabled()
  return flag(vim.g.vimtex_notify_enabled, false)
end

local function options()
  return vim.g.vimtex_notify or {}
end

local function get_backend()
  if backend then
    return backend
  end
  local ok, notify = pcall(require, "notify")
  if ok and type(notify.instance) == "function" then
    backend = notify.instance {
      top_down = false,
      stages = "static",
    }
  else
    backend = vim.notify
  end
  return backend
end

local function stop_timer()
  if timer then
    if not timer:is_closing() then
      timer:stop()
      timer:close()
    end
    timer = nil
  end
end

local function clear()
  stop_timer()
  current = nil
end

local function send(message, level, opts)
  return get_backend()(message, level, opts or {})
end

local function finish(message, level)
  stop_timer()
  local notification = current
  current = nil
  if notification then
    pcall(send, message, level, {
      replace = notification,
      timeout = options().timeout,
    })
  elseif enabled() then
    send(message, level, { timeout = options().timeout })
  end
end

local function compiling()
  if not enabled() or not flag(options().compile, true) then
    return
  end
  clear()
  local open = true
  local index = 1
  local notification
  notification =
    send("Compiling... " .. spinner_frames[index], vim.log.levels.INFO, {
      timeout = false,
      on_close = function()
        open = false
        if current == notification then
          clear()
        end
      end,
    })
  current = notification

  -- The built-in vim.notify does not return a replaceable notification id.
  -- Keep the useful start/finish messages, but only animate capable backends.
  if not notification or not flag(options().spinner, true) then
    return
  end
  timer = vim.uv.new_timer()
  timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      if not enabled() or not open or current ~= notification then
        clear()
        return
      end
      index = index % #spinner_frames + 1
      local ok, replacement = pcall(
        send,
        "Compiling... " .. spinner_frames[index],
        vim.log.levels.INFO,
        { replace = notification, timeout = false }
      )
      if not ok then
        clear()
        return
      end
      if replacement then
        notification = replacement
        current = replacement
      end
    end)
  )
end

function M.enable(silent)
  vim.g.vimtex_notify_enabled = 1
  if not silent then
    send("VimTeX notifications: ON", vim.log.levels.INFO, {
      timeout = options().timeout,
    })
  end
end

function M.disable(silent)
  vim.g.vimtex_notify_enabled = 0
  clear()
  if not silent then
    send("VimTeX notifications: OFF", vim.log.levels.INFO, {
      timeout = options().timeout,
    })
  end
end

function M.toggle()
  if enabled() then
    M.disable()
  else
    M.enable()
  end
end

function M.setup()
  if initialized then
    return
  end
  initialized = true

  vim.api.nvim_create_user_command("VimtexNotifyToggle", M.toggle, {})
  vim.api.nvim_create_user_command("VimtexNotifyEnable", function()
    M.enable()
  end, {})
  vim.api.nvim_create_user_command("VimtexNotifyDisable", function()
    M.disable()
  end, {})

  local group = vim.api.nvim_create_augroup("vimtex_notify", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventCompiling",
    callback = compiling,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventCompileSuccess",
    callback = function()
      if enabled() and flag(options().compile, true) then
        finish("Compile Success", vim.log.levels.INFO)
      else
        clear()
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventCompileFailed",
    callback = function()
      if enabled() and flag(options().compile, true) then
        finish("Compile Failed", vim.log.levels.ERROR)
      else
        clear()
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventCompileStopped",
    callback = function()
      if enabled() and flag(options().compile, true) then
        finish("Compile Stopped", vim.log.levels.WARN)
      else
        clear()
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VimtexEventCleanFinished",
    callback = function()
      if enabled() and flag(options().clean, true) then
        send("Clean Success", vim.log.levels.INFO, {
          timeout = options().timeout,
        })
      end
    end,
  })
end

return M
