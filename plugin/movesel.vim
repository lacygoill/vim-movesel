vim9script

if exists('g:loaded_movesel')
    finish
endif
g:loaded_movesel = 1

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
sil! MapMeta('h', '<c-\><c-n><cmd>call movesel#move("left")<cr>', 'x', 'u')
sil! MapMeta('j', '<c-\><c-n><cmd>call movesel#move("down")<cr>', 'x', 'u')
sil! MapMeta('k', '<c-\><c-n><cmd>call movesel#move("up")<cr>', 'x', 'u')
sil! MapMeta('l', '<c-\><c-n><cmd>call movesel#move("right")<cr>', 'x', 'u')

# Duplication

xno <unique> mdk <c-\><c-n><cmd>call movesel#duplicate('up')<cr>
xno <unique> mdj <c-\><c-n><cmd>call movesel#duplicate('down')<cr>
# works only on visual blocks
xno <unique> mdh <c-\><c-n><cmd>call movesel#duplicate('left')<cr>
xno <unique> mdl <c-\><c-n><cmd>call movesel#duplicate('right')<cr>

