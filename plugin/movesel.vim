vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

import MapMeta from 'lg/map.vim'

# Originally forked from:
# https://github.com/zirrostig/vim-schlepp

# Alternative plugins:
#
# https://github.com/t9md/vim-textmanip
# https://github.com/matze/vim-move

# Movement

# Do not use `C-[hjkl]`!{{{
#
# They are too easily pressed by accident  in visual-block mode, when we want to
# expand  the selection  and release  CTRL  a little  too late;  which leads  to
# unexpected motions of text.
#}}}
sil! MapMeta('k', '<cmd>call movesel#move("up")<cr>', 'x', 'u')
sil! MapMeta('j', '<cmd>call movesel#move("down")<cr>', 'x', 'u')
sil! MapMeta('h', '<cmd>call movesel#move("left")<cr>', 'x', 'u')
sil! MapMeta('l', '<cmd>call movesel#move("right")<cr>', 'x', 'u')

# Duplication

xno <unique> mdk <cmd>call movesel#duplicate('up')<cr>
xno <unique> mdj <cmd>call movesel#duplicate('down')<cr>
# works only on visual blocks
xno <unique> mdh <cmd>call movesel#duplicate('left')<cr>
xno <unique> mdl <cmd>call movesel#duplicate('right')<cr>

