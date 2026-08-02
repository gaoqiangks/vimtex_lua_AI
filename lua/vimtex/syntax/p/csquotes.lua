local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_csquotes() abort
  syntax match texCmdQuote nextgroup=texQuoteArg skipwhite skipnl "\\\%(foreign\|hyphen\)textcquote\>\*\?"
  syntax match texCmdQuote nextgroup=texQuoteArg skipwhite skipnl "\\\%(foreign\|hyphen\)blockcquote\>"
  syntax match texCmdQuote nextgroup=texQuoteArg skipwhite skipnl "\\hybridblockcquote\>"
  call VimtexSyntaxCore_new_arg('texQuoteArg', {'next': 'texRefOpt,texRefArg', 'opts': 'contained transparent'})

  highlight def link texCmdQuote texCmd
endfunction
call VimtexSyntaxPackage_csquotes()
delfunction VimtexSyntaxPackage_csquotes
  ]==]
end

return M
