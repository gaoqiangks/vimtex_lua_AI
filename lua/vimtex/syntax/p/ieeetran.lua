local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_ieeetran() abort
  lua require("vimtex.syntax.packages").load('ieeetrantools')
endfunction
call VimtexSyntaxPackage_ieeetran()
delfunction VimtexSyntaxPackage_ieeetran
  ]==]
end

return M
