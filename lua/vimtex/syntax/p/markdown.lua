local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_markdown() abort
  call VimtexSyntaxCore_new_env({
        \ 'name': 'markdown',
        \ 'region': 'texMarkdownZone',
        \ 'contains': 'texCmd',
        \ 'nested': 'markdown',
        \})

  syntax match texCmdInput "\\markdownInput\>"
        \ nextgroup=texFileArg skipwhite skipnl
endfunction
call VimtexSyntaxPackage_markdown()
delfunction VimtexSyntaxPackage_markdown
  ]==]
end

return M
