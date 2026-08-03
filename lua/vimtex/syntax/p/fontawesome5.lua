local M = {}

local function load_symbols()
  local file = require("vimtex.paths").asset "json/fontawesome.json"
  local lines = require("vimtex.util").readfile(file)
  return vim.json.decode(table.concat(lines))
end

local function cased(name)
  return (name:gsub("^%l", string.upper):gsub("%-(%l)", string.upper))
end

function M.load(config)
  if config.conceal == 0 or config.conceal == false then
    return
  end
  vim.fn["VimtexSyntaxCore_new_opt"]("texFontawesomeOpt", {
    contains = "",
    opts = "conceal contained containedin=texCmdFontawesome",
  })
  vim.fn["VimtexSyntaxCore_new_arg"]("texFontawesomeArg", {
    contains = "",
    opts = "conceal contained containedin=texCmdFontawesome",
  })

  local symbols = load_symbols()
  local commands = {}
  for name, symbol in pairs(symbols.regular) do
    local pattern = [[\v\\fa]]
      .. cased(name)
      .. [[>%(\[\w*\])?|\\faIcon%(\[\w*\])?\{]]
      .. name
      .. [[\}]]
    commands[#commands + 1] = ([[syntax match texCmdFontawesome "%s" conceal cchar=%s]]):format(
      pattern,
      symbol
    )
  end
  for name, symbol in pairs(symbols.starred) do
    local pattern = [[\v\\fa]]
      .. cased(name)
      .. [[\*%(\[\w*\])?|\\faIcon\*%(\[\w*\])?\{]]
      .. name
      .. [[\}]]
    commands[#commands + 1] = ([[syntax match texCmdFontawesome "%s" conceal cchar=%s]]):format(
      pattern,
      symbol
    )
  end
  commands[#commands + 1] =
    [[syntax match texCmdFontawesome "\v\\faIcon%(\[\w*\])?\s*\{500px\}" conceal cchar=]]
  commands[#commands + 1] = "highlight def link texCmdFontawesome texCmd"
  commands[#commands + 1] = "highlight def link texFontawesomeArg texArg"
  commands[#commands + 1] = "highlight def link texFontawesomeOpt texOpt"
  vim.cmd(table.concat(commands, "\n"))
end

return M
