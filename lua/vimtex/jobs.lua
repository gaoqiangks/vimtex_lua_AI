local M = {}
local active = {}
local next_id = 0

local paths = require "vimtex.paths"

local Job = {}
Job.__index = Job

local function shell_command(command)
  if vim.fn.has "win32" == 1 then
    return { "cmd.exe", "/s", "/c", command }
  end
  return { "sh", "-c", command }
end

local function default_cwd()
  local state = vim.b.vimtex
  return type(state) == "table" and state.root or nil
end

local function clean_lines(output)
  local lines = vim.split(output or "", "\n", { plain = true })
  while lines[1] == "" do
    table.remove(lines, 1)
  end
  while lines[#lines] == "" do
    table.remove(lines)
  end
  if vim.fn.has "win32" == 1 then
    for index, line in ipairs(lines) do
      lines[index] = line:gsub("\r$", "")
    end
  end
  return lines
end

function Job:start()
  self.handle = vim.system(shell_command(self.cmd_raw), {
    cwd = self.cwd ~= "" and self.cwd or nil,
    detach = self.detached,
    text = true,
  }, function(result)
    self.result = result
    self.completed = true
  end)
  self.job = self.handle.pid
  vim.wait(100, function()
    return self.completed
  end, 10)
  return self
end

function Job:stop()
  if self.handle and not self.completed then
    self.handle:kill(15)
    self.completed = true
  end
end

function Job:wait()
  if not self.handle or self.completed then
    return self.result
  end

  local result = self.handle:wait(self.wait_timeout)
  if result then
    self.result = result
    self.completed = true
  else
    vim.notify(
      "VimTeX job timed out while waiting: " .. self.cmd_raw,
      vim.log.levels.WARN
    )
    self:stop()
  end
  return self.result
end

function Job:is_running()
  return self.handle ~= nil and not self.completed
end

function Job:get_pid()
  return self.handle and self.handle.pid or 0
end

function Job:signal_hup()
  if self.handle and not self.completed then
    self.handle:kill(1)
  end
end

function Job:output()
  local result = self:wait()
  if not self.capture_output or not result then
    return {}
  end
  return clean_lines((result.stdout or "") .. (result.stderr or ""))
end

function Job:__pprint()
  return {
    { "pid", self:get_pid() > 0 and self:get_pid() or "-" },
    { "cmd", self.cmd_raw },
  }
end

function M.start(command, opts)
  opts = opts or {}
  local job = setmetatable({
    cmd_raw = command,
    cwd = opts.cwd == nil and default_cwd() or opts.cwd,
    wait_timeout = tonumber(opts.wait_timeout) or 5000,
    capture_output = opts.capture_output == true,
    detached = opts.detached == true,
    completed = false,
  }, Job):start()
  next_id = next_id + 1
  active[next_id] = job
  return next_id
end

function M.stop(id)
  if active[id] then
    active[id]:stop()
  end
end

function M.wait(id)
  return active[id] and active[id]:wait() or nil
end

function M.is_running(id)
  return active[id] ~= nil and active[id]:is_running()
end

function M.get_pid(id)
  return active[id] and active[id]:get_pid() or 0
end

function M.signal_hup(id)
  if active[id] then
    active[id]:signal_hup()
  end
end

function M.output(id)
  return active[id] and active[id]:output() or {}
end

function M.pprint(id)
  return active[id] and active[id]:__pprint() or {}
end

local saved_shell

function M.shell_default()
  if vim.fn.has "win32" == 0 then
    return
  end
  saved_shell = { vim.o.shell, vim.o.shellcmdflag, vim.o.shellslash }
  vim.o.shell = "cmd.exe"
  vim.o.shellcmdflag = "/s /c"
  vim.o.shellslash = false
end

function M.shell_restore()
  if saved_shell then
    vim.o.shell, vim.o.shellcmdflag, vim.o.shellslash = unpack(saved_shell)
  end
end

function M.run(command, opts)
  opts = opts or {}
  paths.pushd(opts.cwd or "")
  local stdout = vim.fn.system(shell_command(command))
  local code = vim.v.shell_error
  paths.popd()
  return { code = code, signal = 0, stdout = stdout, stderr = "" }
end

function M.capture(command, opts)
  local result = M.run(command, opts)
  return clean_lines((result.stdout or "") .. (result.stderr or ""))
end

function M.cached(command)
  local store = require("vimtex.cache").open "capture"
  if store:has(command) then
    return store:get(command)
  end
  return store:set(command, M.capture(command))
end

return M
