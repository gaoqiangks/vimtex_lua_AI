local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_circuitikz() abort
  lua require("vimtex.syntax.packages").load('tikz')
  syntax match texTikzEnvBgn "\\begin{circuitikz}"
        \ nextgroup=texTikzOpt skipwhite skipnl
        \ contains=texCmdEnv
  call VimtexSyntaxCore_new_env({
        \ 'name': 'circuitikz',
        \ 'region': 'texTikzZone',
        \ 'contains': '@texClusterTikz',
        \ 'transparent': v:true,
        \})
endfunction
call VimtexSyntaxPackage_circuitikz()
delfunction VimtexSyntaxPackage_circuitikz
  ]==]
end

return M
