local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_ieeeconf() abort
  lua require("vimtex.syntax.packages").load('ieeetrantools')
endfunction
call VimtexSyntaxPackage_ieeeconf()
delfunction VimtexSyntaxPackage_ieeeconf
  ]==]
end

return M
