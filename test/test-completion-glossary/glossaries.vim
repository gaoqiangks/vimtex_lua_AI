set nocompatible
let &rtp = '../..,' . &rtp
filetype plugin on

set nomore

nnoremap q :qall!<cr>

silent edit glossaries.tex

if empty($INMAKE) | finish | endif

let s:candidates = v:lua.require('vimtex.test').completion('\gls{', '')
call assert_equal(len(s:candidates), 7)

" Allow completion for custom keys (#1489)
let s:candidates = v:lua.require('vimtex.test').completion('\Glsentrymaccusative{', '')
call assert_equal(len(s:candidates), 7)

" Allow acronym and extended gls syntax (#1582)
let s:candidates = v:lua.require('vimtex.test').completion('\ac{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\acr{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\ACR{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\cgls{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\pgls{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\dgls{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\rgls{', '')
call assert_equal(len(s:candidates), 7)

let s:candidates = v:lua.require('vimtex.test').completion('\glsname{', '')
call assert_equal(len(s:candidates), 7)

call v:lua.require('vimtex.test').finished()
