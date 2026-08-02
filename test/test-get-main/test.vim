set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

call v:lua.require('vimtex.log').set_silent()

" Ugly paths
call v:lua.require('vimtex.test').main('test-ugly-paths/[code college-1] title/test.tex',
      \ 'test-ugly-paths/[code college-1] title/test.tex')

" Simple recursion
call v:lua.require('vimtex.test').main('simple.tex', 'simple.tex')

" Respect the TeX Root directive
call v:lua.require('vimtex.test').main('test-texroot/included.tex', 'test-texroot/main.tex')

" Note: Even "something.tex" should use the proposed main file even if it is
"       not included.
for s:filename in [
      \ 'test-latexmain/included.tex',
      \ 'test-latexmain/section1/main.tex',
      \ 'test-latexmain/something.tex']
  call v:lua.require('vimtex.test').main(s:filename, 'test-latexmain/main.tex')
endfor

" Test recursive searching and included files with subfiles
for s:filename in [
    \ 'test-includes/test/sub/include2.tex',
    \ 'test-includes/include3.tex',
    \ 'test-includes/subfile.tex']
  call v:lua.require('vimtex.test').main(s:filename, 'test-includes/main.tex')
endfor

" Test subfiles 1: Recursive search
call v:lua.require('vimtex.test').main('test-subfiles/sub/sub1.tex', 'test-subfiles/main.tex')

" Test subfiles 2: Recursive search, but the match does not include sub2
call v:lua.require('vimtex.test').main('test-subfiles/sub/sub2.tex', 'test-subfiles/sub/sub2.tex')

" Test subfiles 3: Recursive search, not .tex extension
call v:lua.require('vimtex.test').main('test-subfiles/sub/sub3.tex', 'test-subfiles/main.tex')

" Test subfiles 4: g:vimtex_subfile_start_local
let g:vimtex_subfile_start_local = 1
call v:lua.require('vimtex.test').main('test-subfiles/sub/sub3.tex', 'test-subfiles/sub/sub3.tex')
let g:vimtex_subfile_start_local = 0

" Test mainfile specified in .latexmrc
call v:lua.require('vimtex.test').main('test-latexmk/preamble.tex', 'test-latexmk/main.tex')

" Test mainfile from bibfiles
call v:lua.require('vimtex.test').main('test-bib-simple/references.bib', 'test-bib-simple/main.tex')
call v:lua.require('vimtex.test').main('test-bib-notfound/references.bib', '')
call v:lua.require('vimtex.test').main('test-bib-alternate/references.bib', '')

execute 'silent edit' fnameescape('test-bib-alternate/main.tex')
call v:lua.require('vimtex.test').main('test-bib-alternate/references.bib', 'test-bib-alternate/main.tex')

" Test standalone
call v:lua.require('vimtex.test').main('test-standalone/a/a.tex', 'test-standalone/main.tex')
call v:lua.require('vimtex.test').main('test-standalone/a/a.tex', 'test-standalone/a/a.tex', 1)

" Test included preamble
call v:lua.require('vimtex.test').main(
      \ './test-included-preamble/preamble.tex',
      \ './test-included-preamble/main.tex')

call v:lua.require('vimtex.test').finished()
