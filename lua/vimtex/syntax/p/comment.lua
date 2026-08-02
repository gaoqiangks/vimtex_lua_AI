local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_comment() abort
  syntax region texComment
        \ start="\\begin{comment}"
        \ end="\\end{comment}"
        \ contains=texCommentEnv
        \ keepend
  syntax match texCommentEnv "\\\%(begin\|end\){comment}"
        \ contained
        \ contains=texCmdEnv
endfunction
call VimtexSyntaxPackage_comment()
delfunction VimtexSyntaxPackage_comment
  ]==]
end

return M
