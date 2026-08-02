set nocompatible
set runtimepath^=../..
filetype plugin on

nnoremap q :qall!<cr>

let g:test = 0

let g:vimtex_view_automatic = 0
let g:vimtex_compiler_method = 'generic'
lua << EOF
vim.g.vimtex_compiler_generic = {
  command = 'make dummy',
  hooks = { function(msg) if msg:match('SillyWalk') then vim.g.test = 1 end end },
}
EOF

call v:lua.require('vimtex.log').set_silent()

silent edit test.tex

if empty($INMAKE) | finish | endif

call v:lua.require('vimtex.compiler').start()
call b:vimtex.compiler.wait()
call assert_equal(1, g:test)

call v:lua.require('vimtex.test').finished()
