local cache = require "vimtex.cache"
local jobs = require "vimtex.jobs"
local paths = require "vimtex.paths"

local M = {}

local function project_root()
  local state = vim.b.vimtex
  return type(state) == "table" and state.root or vim.fn.getcwd()
end

function M.run(args)
  local output = jobs.capture("kpsewhich " .. args, { cwd = project_root() })
  return vim.tbl_filter(function(line)
    return not line:find("kpsewhich: warning: ", 1, true)
  end, output)
end

function M.find(file)
  local store = cache.open("kpsewhich", { default = {} })
  local root = project_root()
  local current = store:get(file)

  if type(current) ~= "table" then
    vim.notify(
      'Invalid kpsewhich cache; clear it with ":VimtexClearCache kpsewhich"',
      vim.log.levels.ERROR
    )
    return ""
  end
  for _, cached in ipairs(current) do
    if cached[2] == "" or cached[2] == root then
      return cached[1]
    end
  end

  local result = M.run(vim.fn.fnameescape(file))[1] or ""
  if not paths.is_abs(result) then
    result = result == "" and "" or paths.s(root .. "/" .. result)
    current[#current + 1] = { result, root }
  else
    current[#current + 1] = { result, "" }
  end
  store.modified = true
  store:write()
  return result
end

return M
