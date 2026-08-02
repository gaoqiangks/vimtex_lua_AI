local M = {}

local function core(name, ...)
  return vim.fn["VimtexSyntaxCore_" .. name](...)
end

function M.load(_)
  core("new_env", {
    name = [[luacode\*\?]],
    region = "texLuaZone",
    contains = "texCmd",
    nested = "lua",
  })
  vim.cmd [[syntax match texCmdLua "\\\%(directlua\|luadirect\)\>" nextgroup=texLuaArg skipwhite skipnl]]
  core("new_arg", "texLuaArg", { contains = "@vimtex_nested_lua,texCmd" })

  local lua_syntax = vim.api.nvim_get_runtime_file("syntax/lua.vim", false)[1]
    or ""
  if lua_syntax:find("runtime/syntax", 1, true) then
    vim.cmd [[syntax match texCmd nextgroup=texOpt,texArg skipwhite skipnl "\\[a-zA-Z@]\+" contained containedin=luaFunctionBlock]]
  else
    vim.cmd "syntax cluster luaStat add=texCmd"
  end
  vim.cmd "highlight def link texCmdLua texCmd"
end

return M
