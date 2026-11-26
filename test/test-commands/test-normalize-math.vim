set nocompatible
set runtimepath^=../..
filetype plugin on
setfiletype tex

let s:original =<< trim END
  中文 \(x\)\(y\); keep $z$ and \$5. % \(comment\)
  \verb|\(literal\) $$literal$$| and \\(escaped\\)
  \begin{verbatim}\(literal\)\end{verbatim}
  $$x = y \eqno(1)$$
  \begin{verbatim}
  $$literal$$ and \[literal\]
  \end{verbatim}
  \[
    a = b % \] is a comment
  \]
  $$
    c = d
  $$
  \begin{displaymath}
    e = f
  \end{displaymath}
  \begin{equation*}
    g = h
  \end{equation*}
  \begin{equation}
    i = j \label{eq:keep}
  \end{equation}
  \begin{align}
    A &= B \label{eq:A} \\
    C &= D \label{eq:C}
  \end{align}
  Outside \(w\) and an empty \(\) formula.
END
let s:expected =<< trim END
  中文 $x$$y$; keep $z$ and \$5. % \(comment\)
  \verb|\(literal\) $$literal$$| and \\(escaped\\)
  \begin{verbatim}\(literal\)\end{verbatim}
  $$x = y \eqno(1)$$
  \begin{verbatim}
  $$literal$$ and \[literal\]
  \end{verbatim}
  \begin{equation}
    a = b % \] is a comment
  \end{equation}
  \begin{equation}
    c = d
  \end{equation}
  \begin{equation}
    e = f
  \end{equation}
  \begin{equation}
    g = h
  \end{equation}
  \begin{equation}
    i = j \label{eq:keep}
  \end{equation}
  \begin{align}
    A &= B \label{eq:A} \\
    C &= D \label{eq:C}
  \end{align}
  Outside $w$ and an empty ${}$ formula.
END

for [s:outer, s:inner, s:body] in [
      \ ['align', 'aligned', ['a &= b \\', 'c &= d']],
      \ ['align*', 'aligned', ['x &= y \\', 'u &= v']],
      \ ['gather*', 'gathered', ['p = q \\', 'r = s']],
      \ ]
  call extend(s:original, ['\begin{' . s:outer . '}'] + s:body + ['\end{' . s:outer . '}'])
  call extend(s:expected, ['\begin{equation}\begin{' . s:inner . '}'] + s:body
        \ + ['\end{' . s:inner . '}\end{equation}'])
endfor

call setline(1, s:original)
" Start a fresh undo block, as when entering the command interactively.
let &undolevels = &undolevels
VimtexNormalizeMath
let s:output = join(getline(1, '$'), "\n")
" Either wrap on the same line or put the inner environment on its own line.
let s:output = substitute(s:output, '\\begin{equation}\zs\_s*\ze\\begin{', '', 'g')
let s:output = substitute(s:output, '\\end{\%(aligned\|gathered\)}\zs\_s*\ze\\end{equation}', '', 'g')
call assert_equal(join(s:expected, "\n"), s:output)

let s:tick = b:changedtick
VimtexNormalizeMath
call assert_equal(s:tick, b:changedtick, 'Normalizing twice should be a no-op')
undo
call assert_equal(s:original, getline(1, '$'), 'One undo should restore the document')

call v:lua.require('vimtex.test').finished()
