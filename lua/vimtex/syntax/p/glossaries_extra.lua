local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_glossaries_extra() abort
  lua require("vimtex.syntax.packages").load('glossaries')
endfunction
call VimtexSyntaxPackage_glossaries_extra()
delfunction VimtexSyntaxPackage_glossaries_extra
  ]==]
end

return M
