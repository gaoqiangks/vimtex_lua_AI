local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_ieeecolor() abort
  lua require("vimtex.syntax.packages").load('ieeetrantools')
endfunction
call VimtexSyntaxPackage_ieeecolor()
delfunction VimtexSyntaxPackage_ieeecolor
  ]==]
end

return M
