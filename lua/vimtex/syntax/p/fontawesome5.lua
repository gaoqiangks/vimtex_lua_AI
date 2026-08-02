local M = {}

local function load_symbols()
  local file = require("vimtex.paths").asset "json/fontawesome.json"
  return vim.json.decode(table.concat(vim.fn.readfile(file)))
end

local function cased(name)
  return vim.fn.substitute(name, [[\v%(^|-)(.)]], [[\u\1]], "g")
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
  for name, symbol in pairs(symbols.regular) do
    local pattern = [[\v\\fa]]
      .. cased(name)
      .. [[>%(\[\w*\])?|\\faIcon%(\[\w*\])?\{]]
      .. name
      .. [[\}]]
    vim.cmd(
      ([[syntax match texCmdFontawesome "%s" conceal cchar=%s]]):format(
        pattern,
        symbol
      )
    )
  end
  for name, symbol in pairs(symbols.starred) do
    local pattern = [[\v\\fa]]
      .. cased(name)
      .. [[\*%(\[\w*\])?|\\faIcon\*%(\[\w*\])?\{]]
      .. name
      .. [[\}]]
    vim.cmd(
      ([[syntax match texCmdFontawesome "%s" conceal cchar=%s]]):format(
        pattern,
        symbol
      )
    )
  end
  vim.cmd [[syntax match texCmdFontawesome "\v\\faIcon%(\[\w*\])?\s*\{500px\}" conceal cchar=]]
  vim.cmd "highlight def link texCmdFontawesome texCmd"
  vim.cmd "highlight def link texFontawesomeArg texArg"
  vim.cmd "highlight def link texFontawesomeOpt texOpt"
end

return M
