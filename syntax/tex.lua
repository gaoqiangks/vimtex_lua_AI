if
  vim.g.vimtex_syntax_enabled == 0
  or vim.b.current_syntax
  or vim.b.vimtex_syntax_loading
then
  return
end
vim.b.vimtex_syntax_loading = true

require("vimtex.options").init()
require "vimtex.util"
require "vimtex.syntax.core"
vim.fn["VimtexSyntaxCore_init_options"]()
vim.fn["VimtexSyntaxCore_init_rules"]()
vim.fn["VimtexSyntaxCore_init_highlights"]()

vim.b.vimtex_syntax_did_postinit = nil
vim.b.vimtex_syntax = vim.empty_dict()
require("vimtex.syntax.nested").reset()
if vim.b.vimtex then
  vim.fn["VimtexSyntaxCore_init_post"]()
end

local group = vim.api.nvim_create_augroup("vimtex_syntax", { clear = false })
vim.api.nvim_clear_autocmds { group = group, buffer = 0 }
vim.api.nvim_clear_autocmds { group = group, event = "User" }
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  buffer = 0,
  callback = function()
    vim.fn["VimtexSyntaxCore_init_highlights"]()
  end,
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "VimtexEventInitPost",
  callback = function()
    vim.fn["VimtexSyntaxCore_init_post"]()
  end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  buffer = 0,
  once = true,
  callback = function(args)
    require("vimtex.syntax.packages").cleanup_buffer(args.buf)
  end,
})

vim.b.vimtex_syntax_loading = nil
