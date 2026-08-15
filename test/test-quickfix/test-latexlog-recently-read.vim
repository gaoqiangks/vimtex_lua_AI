set nocompatible
let &rtp = '../..,' . &rtp

let s:log = tempname()
call writefile([
      \ './main.tex:269: Undefined control sequence.',
      \ '<recently read> \mathcla ',
      \ '                         ',
      \ 'l.269     Let $\mathcla',
      \ '                       {L}_1$ be a subspace.',
      \ ], s:log)

silent edit ../example-quickfix/main.tex
call v:lua.require('vimtex.qf.latexlog').addqflist(expand('%:p'), s:log)

let s:qf = getqflist()
call assert_equal(1, len(s:qf))
call assert_equal(269, s:qf[0].lnum)
call assert_equal('E', s:qf[0].type)
call assert_equal("Undefined control sequence.\n\\mathcla ", s:qf[0].text)

call delete(s:log)
call v:lua.require('vimtex.test').finished()
