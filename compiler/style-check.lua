if vim.b.current_compiler then
  return
end
vim.b.current_compiler = "style-check"

vim.bo.makeprg = "style-check.rb %:S"
vim.bo.errorformat = "%f:%l:%c: %m,%-G%.%#"
