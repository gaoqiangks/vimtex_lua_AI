local M = {}

local function read_log()
  return vim.fn.readfile "prof.log"
end

function M.start()
  vim.cmd "profile start prof.log"
  vim.cmd "profile func *"
end

function M.stop()
  vim.cmd "profile stop"
end

function M.open()
  vim.cmd.silent "edit prof.log"
end

function M.print()
  for _, line in ipairs(read_log()) do
    print(line)
  end
  print ""
  vim.cmd "quit!"
end

function M.file(filename)
  M.start()
  vim.api.nvim_cmd(
    { cmd = "edit", args = { filename }, mods = { silent = true } },
    {}
  )
  M.stop()
end

function M.command(command)
  M.start()
  vim.cmd(command)
  M.stop()
end

function M.filter(sections)
  local lines = read_log()
  local result = {}
  for _, name in ipairs(sections) do
    local active = false
    for _, line in ipairs(lines) do
      if active and line:match "^FUNCTION" and not line:match(name) then
        active = false
      elseif active then
        result[#result + 1] = line
      elseif line:match(name) then
        result[#result + 1] = line
        active = true
      end
    end
    if active then
      result[#result + 1] = " "
    end
  end
  vim.fn.writefile(result, "prof.log")
end

function M.time(previous, message)
  local current = vim.uv.hrtime() / 1e9
  if previous then
    print(("%s: %8.5f\n"):format(message or "Time elapsed", current - previous))
  end
  return current
end

_G.vimtex_profile_time = M.time

return M
