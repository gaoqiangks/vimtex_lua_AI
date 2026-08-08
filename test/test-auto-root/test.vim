set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

call v:lua.require('vimtex.log').set_silent()

let g:vimtex_root_auto_add_enabled = 1

silent edit included.tex
sleep 10m
call assert_equal('% !TeX root = main.tex', getline(1))
call assert_equal(1, b:vimtex_root_auto_added)
call assert_equal(1, &modified)
bwipeout!

silent edit sub/nested.tex
sleep 10m
call assert_equal('% !TeX root = ../main.tex', getline(1))
call assert_equal(1, b:vimtex_root_auto_added)
bwipeout!

silent edit disabled.tex
call assert_equal('% !TeX root = nil', getline(1))
call assert_false(exists('b:vimtex_root_auto_added'))
bwipeout!

silent edit main.tex
call assert_equal('\documentclass{article}', getline(1))
call assert_false(exists('b:vimtex_root_auto_added'))
bwipeout!

let g:vimtex_root_auto_add_enabled = 0
silent edit off.tex
call assert_equal('Content with the feature disabled.', getline(1))
call assert_false(exists('b:vimtex_root_auto_added'))
bwipeout!

call v:lua.require('vimtex.test').finished()
