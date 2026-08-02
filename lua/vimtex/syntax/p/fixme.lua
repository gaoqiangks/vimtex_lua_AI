local M = {}

function M.load(_)
  vim.cmd [==[
function! VimtexSyntaxPackage_fixme() abort
  let l:authors = v:lua.require('vimtex.parser.fixme').authors()

  " Base inline command and environment
  syntax match texCmdTodo '\\fixme\>\*\?' nextgroup=texFixmeArg
  syntax match texFixmeTodoEnvBgn "\\begin{afixme}"
        \ nextgroup=texFixmeArg skipwhite skipnl
  syntax match texFixmeTodoEnvEnd "\\end{afixme}"

  " Per-author commands and environments, by severity. The base author uses the
  " "fx"/"anfx" prefixes; authors registered with \FXRegisterAuthor add their
  " own. See also v:lua.require('vimtex.parser.fixme').authors().
  let l:sev_cmd = #{
        \ note: 'texCmdTodo',
        \ warning: 'texCmdWarning',
        \ error: 'texCmdError',
        \ fatal: 'texCmdFatal',
        \}
  let l:sev_env = #{
        \ note: 'texFixmeTodoEnv',
        \ warning: 'texFixmeWarningEnv',
        \ error: 'texFixmeErrorEnv',
        \ fatal: 'texFixmeFatalEnv',
        \}

  for l:prefix in l:authors.cmd
    for [l:sev, l:grp] in items(l:sev_cmd)
      execute 'syntax match' l:grp
            \ "'\\\\" . l:prefix . l:sev . "\\>\\*\\?'"
            \ 'nextgroup=texFixmeArg'
    endfor
  endfor

  for l:prefix in l:authors.env
    for [l:sev, l:grp] in items(l:sev_env)
      execute 'syntax match' l:grp . 'Bgn'
            \ '"\\begin{' . l:prefix . l:sev . '\*\?}"'
            \ 'nextgroup=texFixmeArg skipwhite skipnl'
      execute 'syntax match' l:grp . 'End'
            \ '"\\end{' . l:prefix . l:sev . '\*\?}"'
    endfor
  endfor

  call VimtexSyntaxCore_new_arg('texFixmeArg', {'contains': 'TOP,@Spell'})

  highlight def link texFixmeTodoEnvBgn texCmdTodo
  highlight def link texFixmeTodoEnvEnd texFixmeTodoEnvBgn
  highlight def link texFixmeWarningEnvBgn texCmdWarning
  highlight def link texFixmeWarningEnvEnd texFixmeWarningEnvBgn
  highlight def link texFixmeErrorEnvBgn texCmdError
  highlight def link texFixmeErrorEnvEnd texFixmeErrorEnvBgn
  highlight def link texFixmeFatalEnvBgn texCmdFatal
  highlight def link texFixmeFatalEnvEnd texFixmeFatalEnvBgn
  highlight def link texFixmeArg texArg
endfunction
call VimtexSyntaxPackage_fixme()
delfunction VimtexSyntaxPackage_fixme
  ]==]
end

return M
