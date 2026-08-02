if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "lacheck"

vim.bo.makeprg = "lacheck %:S"
vim.bo.errorformat = '"%f", line %l: %m'
