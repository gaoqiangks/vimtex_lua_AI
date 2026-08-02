require("vimtex.ftplugin").setup()

if
  vim.g.vimtex_syntax_enabled == 1
  and vim.g.vimtex_syntax_conceal_disable ~= 1
then
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(0) then
      require("vimtex.nvim").check_treesitter(0)
    end
  end, 1000)
end
