local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_beamer() abort
  syntax match texBeamerDelim '<\|>' contained
  syntax match texBeamerOpt '<[^>]*>' contained contains=texBeamerDelim

  syntax match texCmdBeamer '\\only\(<[^>]*>\)\?' contains=texBeamerOpt
  syntax match texCmdItem '\\item<[^>]*>' contains=texBeamerOpt

  syntax match texCmdInput "\\includegraphics<[^>]*>"
        \ contains=texBeamerOpt
        \ nextgroup=texFileOpt,texFileArg

  call VimtexSyntaxCore_new_env({
        \ 'name': 'semiverbatim',
        \ 'region': 'texVerbZone'
        \})

  highlight link texCmdBeamer texCmd
  highlight link texBeamerOpt texOpt
  highlight link texBeamerDelim texDelim
endfunction
call VimtexSyntaxPackage_beamer()
delfunction VimtexSyntaxPackage_beamer
  ]==]
end

return M
