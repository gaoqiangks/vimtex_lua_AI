set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on
syntax on

set nomore

setfiletype tex

call v:lua.require('vimtex.test').keys('02f+d2ac',
      \ 'a + \bar{\mathit{c + d}} =',
      \ 'a +  =')

call v:lua.require('vimtex.test').keys('fdd2ad',
      \ 'a + \left(b + \left[c + d \right] + e\right) + f',
      \ 'a +  + f')

call v:lua.require('vimtex.test').keys('f\dac',
      \ 'a + \test[opt1][opt2]{arg} + f',
      \ 'a +  + f')

call v:lua.require('vimtex.test').keys('f\dac',
      \ 'a + \; f',
      \ 'a +  f')

call v:lua.require('vimtex.test').keys('di$',
      \ 'Hello world! $(x)$',
      \ 'Hello world! $$')

call v:lua.require('vimtex.test').keys('da$',
      \ 'Hello world! $(x)$',
      \ 'Hello world! ')

call v:lua.require('vimtex.test').keys('vi$d',
      \ 'Hello world! $(x)$',
      \ 'Hello world! $$')

call v:lua.require('vimtex.test').keys('va$d',
      \ 'Hello world! $(x)$',
      \ 'Hello world! ')

call v:lua.require('vimtex.test').keys('jjva$d',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('jjvi$d',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '$$',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('jjda$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'Hello world!',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'Hello world!',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('jjfxda$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '\begin{equation} x \end{equation}',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('jjda$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '\begin{equation} x \end{equation}',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   'z',
      \   '',
      \   '$y$',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('Gkda$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '$d$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('Gk2da$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '$d$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('Gk3da$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '$d$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').keys('Gk3di$',
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '$d$',
      \   '\end{document}',
      \ ],
      \ [
      \   '\documentclass{minimal}',
      \   '\begin{document}',
      \   '$a$',
      \   '$b$',
      \   '$c$',
      \   '$$',
      \   '\end{document}',
      \ ],
      \)

call v:lua.require('vimtex.test').finished()
