if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "textidote"

require("vimtex.options").init()
local ui = require "vimtex.ui"
local config = vim.g.vimtex_grammar_textidote
local jar = vim.fn.fnamemodify(config.jar, ":p")

if config.jar == "" or vim.fn.filereadable(jar) ~= 1 then
  vim.notify(
    "g:vimtex_grammar_textidote is not configured; see :help vimtex-grammar-textidote",
    vim.log.levels.ERROR
  )
  return
end

local language = ui.select(vim.split(vim.wo.spelllang, ",", { plain = true }), {
  prompt = "Multiple spelllang languages detected, please select one:",
  force_choice = true,
})
if language == "en_gb" then
  language = "en_UK"
else
  local base, region = language:match "^(%a%a)_?(%a%a?)"
  language = base or language
  if region and #region == 2 then
    language = language .. "_" .. region:upper()
  end
end

vim.bo.makeprg = "java -jar "
  .. vim.fn.shellescape(jar)
  .. (config.args and " " .. config.args or "")
  .. " --no-color --output singleline --check "
  .. language
  .. " %:S"
vim.bo.errorformat = [[%f(L%lC%c-L%\d%\+C%\d%\+): %m,%-G%.%#]]
