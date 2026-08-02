source common.vim

EditConcealed test-dockerfile.tex

if empty($INMAKE) | finish | endif

call assert_notequal('# %s', &commentstring)

call v:lua.require('vimtex.test').finished()
