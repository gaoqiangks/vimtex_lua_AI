if vim.g.vimtex_enabled == nil or vim.g.vimtex_enabled == 1 then
  if vim.g.tex_flavor == nil or vim.g.tex_flavor == "latex" then
    vim.g.tex_flavor = "latex"
  end

  local group =
    vim.api.nvim_create_augroup("vimtex_filetypes", { clear = true })
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = group,
    pattern = { "*.cls", "*.tikz" },
    callback = function(event)
      vim.bo[event.buf].filetype = "tex"
    end,
  })
end
