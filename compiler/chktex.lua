if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "chktex"

require("vimtex.options").init()
vim.bo.makeprg = ("chktex --quiet --verbosity=4 %s %s"):format(
  vim.g.vimtex_lint_chktex_parameters,
  vim.g.vimtex_lint_chktex_ignore_warnings
)
vim.bo.errorformat = '%A"%f", line %l: %m,%-Z%p^,%-C%.%#'
