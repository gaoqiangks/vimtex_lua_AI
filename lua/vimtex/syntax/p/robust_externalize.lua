local M = {}

local function core(name, ...)
  return vim.fn["VimtexSyntaxCore_" .. name](...)
end

function M.load(config)
  require("vimtex.syntax.packages").load "tikz"
  vim.cmd [[syntax match texRobExtEnvBgn contained '\\begin{\%(RobExt\)\?CacheMeCode\|CacheMe}' nextgroup=texRobExtEnvOpt,texRobExtEnvArg skipwhite skipnl contains=texCmdEnv]]
  core("new_opt", "texRobExtEnvOpt", { next = "texRobExtEnvArg" })
  core("new_arg", "texRobExtEnvArg", { contains = "texRobExtEnvArg" })
  for _, name in ipairs {
    [[\%(RobExt\)\?CacheMeCode\|CacheMe]],
    "PlaceholderPathFromCode",
    [[SetPlaceholderCode\*\?]],
  } do
    core("new_env", {
      name = name,
      region = "texRobExtZone",
      contains = "texCmdEnv,texRobExtEnvBgn",
    })
  end

  for _, preset in ipairs(config.presets or {}) do
    local preset_name, target = preset[1], preset[2]
    local name, contains
    if target == "" then
      name = "Verb"
      contains = "contains=texCmdEnv,texRobExtEnvBgn"
    elseif target == "TOP" then
      name = "LaTeX"
      contains = "contains=TOP,texRobExtZone"
    else
      name = target:sub(1, 1):upper() .. target:sub(2)
      local cluster = target:sub(1, 1) == "@" and target
        or require("vimtex.syntax.nested").include(target)
      contains = "contains=texCmdEnv,texRobExtEnvBgn," .. cluster
    end
    local group = "texRobExtZone" .. name
    local start = [[\\begin{\z(\%(RobExt\)\?CacheMeCode\|CacheMe\)}\_s*{]]
      .. preset_name
      .. "[ ,}]"
    vim.cmd(
      ([[syntax region %s start="%s" end="\\end{\z1}" keepend %s]]):format(
        group,
        start,
        contains
      )
    )
    if target == "" then
      vim.cmd("highlight def link " .. group .. " texRobExtZone")
    end
  end

  vim.cmd "highlight def link texRobExtEnvArg texSymbol"
  vim.cmd "highlight def link texRobExtEnvArgOpt texOpt"
  vim.cmd "highlight def link texRobExtEnvOpt texOpt"
  vim.cmd "highlight def link texRobExtZone texZone"
end

return M
