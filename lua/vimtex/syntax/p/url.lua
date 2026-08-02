local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_url() abort
  lua require("vimtex.syntax.packages").load('hyperref')
endfunction
call VimtexSyntaxPackage_url()
delfunction VimtexSyntaxPackage_url
  ]==]
end

return M
