set nocompatible
set noswapfile
set runtimepath^=../..
filetype plugin on

let s:old = '\(old\) | \[outside\]'

function! s:setup(ft)
  enew!
  call setline(1, s:old)
  execute 'setfiletype ' . a:ft
  call cursor(1, stridx(s:old, '|') + 1)
  let &undolevels = &undolevels
endfunction

call s:setup('tex')
call nvim_paste('\(x\) and $$y$$', v:false, -1)
call assert_equal('\(old\) |$x$ and \begin{equation}y\end{equation} \[outside\]', getline(1))
let s:endcol = stridx(getline(1), ' \[outside') + 1
call assert_equal(s:endcol - 1, col("']"), 'Put end follows the expanded equation')
call assert_equal(col("']"), col('.'), 'Normal-mode paste leaves the cursor at its end')
undo
call assert_equal([s:old], getline(1, '$'), 'Undo the paste and its normalization together')

" A control sequence can be split across two chunks of terminal input.
call s:setup('tex')
call nvim_paste('\', v:false, 1)
call nvim_paste("(x\\)\n\\[", v:false, 2)
call nvim_paste("z\\]", v:false, 3)
call assert_equal(['\(old\) |$x$', '\begin{equation}z\end{equation} \[outside\]'], getline(1, '$'))

" Native puts should preserve the named register, count, and register type.
call s:setup('tex')
call setreg('a', '\(r\)', 'v')
normal "a2p
call assert_equal('\(old\) |$r$$r$ \[outside\]', getline(1))
call assert_equal('\(r\)', getreg('a'))

call s:setup('tex')
call setreg('a', ['\[', 't', '\]'], 'V')
normal "aP
call assert_equal(['\begin{equation}', 't', '\end{equation}', s:old], getline(1, '$'))
call assert_equal('V', getregtype('a'))
call assert_equal(['\[', 't', '\]'], getreg('a', 1, 1))

" Paste while the editor is in Insert mode, as with terminal bracketed paste.
call s:setup('tex')
execute "normal! i\<Cmd>call nvim_paste('\\(i\\)', v:false, -1)\<CR>\<Esc>"
call assert_equal('\(old\) $i$| \[outside\]', getline(1))

" Only complete formula pairs inside the inserted text may be replaced.
call s:setup('tex')
call setline(1, 'Start \(x')
normal! $
call nvim_paste('\), then \(y\)', v:false, -1)
call assert_equal('Start \(x\), then $y$', getline(1))

" Use the insertion site's LaTeX context even when outside the pasted text.
call s:setup('tex')
call setline(1, 'Text. % comment')
normal! $
call nvim_paste(' \(x\)', v:false, -1)
call assert_equal('Text. % comment \(x\)', getline(1))

call s:setup('tex')
call setline(1, ['\begin{verbatim}', 'literal:', '\end{verbatim}'])
call cursor(2, 8)
call setreg('a', ' \(x\)', 'v')
normal "ap
call assert_equal('literal: \(x\)', getline(2))

call s:setup('tex')
let g:vimtex_env_normalize_on_paste = 0
call nvim_paste('\(raw\)', v:false, -1)
call assert_equal('\(old\) |\(raw\) \[outside\]', getline(1))
let g:vimtex_env_normalize_on_paste = 1

call s:setup('text')
call nvim_paste('\(x\)', v:false, -1)
call setreg('a', '\(r\)', 'v')
normal "ap
call assert_equal('\(old\) |\(x\)\(r\) \[outside\]', getline(1))

call v:lua.require('vimtex.test').finished()
