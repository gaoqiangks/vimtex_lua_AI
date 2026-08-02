local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_pdfpages() abort
  syntax match texCmdInput "\\includepdf\>" nextgroup=texFileOpt,texFileArg skipwhite skipnl
endfunction
call VimtexSyntaxPackage_pdfpages()
delfunction VimtexSyntaxPackage_pdfpages
  ]==]
end

return M
