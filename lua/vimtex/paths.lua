local M = {}

local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(source)))
local stack = {}

local function cd_command()
  if vim.fn.haslocaldir() == 1 then
    return "lcd"
  end
  if vim.fn.exists ":tcd" == 2 and vim.fn.haslocaldir(-1) == 1 then
    return "tcd"
  end
  return "cd"
end

function M.asset(name)
  return M.join(root, "assets/" .. name)
end

function M.pushd(path)
  if
    not path
    or path == ""
    or vim.fn.getcwd() == vim.fn.fnamemodify(path, ":p")
  then
    stack[#stack + 1] = ""
    return
  end

  stack[#stack + 1] = vim.fn.getcwd()
  vim.cmd(cd_command() .. " " .. vim.fn.fnameescape(path))
end

function M.popd()
  local path = table.remove(stack)
  if path and path ~= "" then
    vim.cmd(cd_command() .. " " .. vim.fn.fnameescape(path))
  end
end

function M.join(base, tail)
  return M.s(base .. "/" .. tail)
end

function M.s(path)
  if vim.fn.exists "+shellslash" == 1 and not vim.o.shellslash then
    path = path:gsub("/", "\\")
  end
  return vim.fn.simplify(path)
end

function M.is_abs(path)
  if vim.fn.has "win32" == 1 then
    return path:match "^%a:[\\/]" ~= nil
  end
  return path:sub(1, 1) == "/"
end

function M.relative(path, current)
  local normalized_target = path:gsub("\\", "/")
  local normalized_current = current:gsub("\\", "/")
  local target = vim.fn.simplify(normalized_target)
  local common = vim.fn.simplify(normalized_current)

  if not M.is_abs(target) then
    return path:gsub("^%./", "", 1)
  end

  if vim.fn.has "win32" == 1 then
    target = target:gsub("^%a:", "", 1)
    common = common:gsub("^%a:", "", 1)
  end
  common = common:gsub("/$", "")

  local tries = 50
  local result = ""
  while target:sub(1, #common) ~= common and tries > 0 do
    common = vim.fn.fnamemodify(common, ":h")
    result = result == "" and ".." or "../" .. result
    tries = tries - 1
  end
  if tries == 0 then
    return path
  end
  if common == "/" then
    result = result .. "/"
  end

  local forward = target:sub(#common + 1)
  if forward ~= "" then
    result = result == "" and forward:sub(2) or result .. forward
  end
  return result
end

function M.shorten_relative(path)
  local state = vim.b.vimtex
  local relative = M.relative(path, state.root)
  return #relative < #path and relative or path
end

return M
