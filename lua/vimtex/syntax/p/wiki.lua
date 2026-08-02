local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_wiki() abort
  call v:lua.require('vimtex.syntax.nested').include('markdown')

  syntax region texWikiZone
        \ start='\\wikimarkup\>'
        \ end='\\nowikimarkup\>'
        \ keepend
        \ transparent
        \ contains=texCmd,@vimtex_nested_markdown
endfunction
call VimtexSyntaxPackage_wiki()
delfunction VimtexSyntaxPackage_wiki
  ]==]
end

return M
