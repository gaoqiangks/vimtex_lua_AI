local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_geometry() abort
  syntax match texCmdGeometry nextgroup=texGeometryArg skipwhite "\\geometry\>"
  call VimtexSyntaxCore_new_arg('texGeometryArg', {'contains': 'texGeometryArg,@texClusterOpt'})

  highlight def link texCmdGeometry texCmd
  highlight def link texGeometryArg texOpt
endfunction
call VimtexSyntaxPackage_geometry()
delfunction VimtexSyntaxPackage_geometry
  ]==]
end

return M
