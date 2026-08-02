local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_import() abort
  syntax match texCmdImport "\%#=1\\\%(sub\)\?import\>"
        \ nextgroup=texImportFileArg skipwhite skipnl

  call VimtexSyntaxCore_new_arg('texImportFileArg', #{
        \ contains: '@NoSpell,texCmd,texComment',
        \ next: 'texFileArg',
        \})

  highlight def link texCmdImport texCmdInput
  highlight def link texImportFileArg texFileArg
endfunction
call VimtexSyntaxPackage_import()
delfunction VimtexSyntaxPackage_import
  ]==]
end

return M
