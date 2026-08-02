source common.vim

let g:vimtex_syntax_custom_cmds = [
      \ {'name': 'footnote', 'argstyle': 'bold'},
      \ {'name': 'cmda', 'conceal': 1, 'optconceal': 0},
      \ {'name': 'cmdb', 'conceal': 1},
      \ {'name': 'mathcmda', 'mathmode': v:true, 'conceal': 1, 'argstyle': 'bold'},
      \ {'name': 'mathcmdb', 'mathmode': v:true, 'conceal': 1},
      \ {'name': 'R', 'mathmode': v:true, 'concealchar': 'ℝ'},
      \ {'name': 'E', 'mathmode': v:true, 'concealchar': '𝔼'},
      \ {'name': 'P', 'mathmode': v:true, 'concealchar': 'ℙ'},
      \ {'name': 'undline', 'argstyle': 'bolditalunder'},
      \ {'name': 'mathnote', 'mathmode': 1,
      \  'nextgroup': 'texMathTextArg', 'hlgroup': 'texMathCmdText'},
      \ {'name': 'mathnoteC', 'mathmode': 1, 'conceal': 1,
      \  'nextgroup': 'texMathTextConcArg', 'hlgroup': 'texMathCmdText'},
      \ {'name': 'mygls', 'argspell': 0},
      \ {'name': 'slurp', 'argspell': 0, 'arggreedy': v:true},
      \ {'name': 'regex', 'cmdre': '[iI]?[aA]c[slaf]?p?\*?', 'conceal': 1},
      \ {'name': 'mather', 'mathmode': 1,
      \  'nextgroup': 'texMatherArg', 'hlgroup': 'texOpt'},
      \]

call v:lua.require('vimtex.syntax').add_to_mathzone_ignore('texMatherArg')

EditConcealed test-custom.tex

call VimtexSyntaxCore_new_arg('texMatherArg', {
      \ 'opts': 'contained keepend'
      \})

if empty($INMAKE) | finish | endif

call assert_true(v:lua.require('vimtex.syntax').in_mathzone(31, 5))
call assert_false(v:lua.require('vimtex.syntax').in_mathzone(31, 15))

call v:lua.require('vimtex.test').finished()
