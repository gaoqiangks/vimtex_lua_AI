local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_todonotes() abort
  syntax match texCmdTodo '\\todo\>' nextgroup=texTodoOpt,texTodoArg

  call VimtexSyntaxCore_new_opt('texTodoOpt', {'next': 'texTodoArg'})
  call VimtexSyntaxCore_new_arg('texTodoArg', {'contains': 'TOP,@Spell'})

  highlight def link texTodoOpt texOpt
endfunction
call VimtexSyntaxPackage_todonotes()
delfunction VimtexSyntaxPackage_todonotes
  ]==]
end

return M
