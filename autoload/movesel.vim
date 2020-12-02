vim9script

# TODO: Once  you've  completely refactored  this  plugin,  in our  vimrc,  move
# `vim-movesel` from the section "To assimilate" to "Done".

# FIXME: https://github.com/zirrostig/vim-schlepp/issues/11

# FIXME:
# We've modified how to reselect a block when moving one to the left/right.
# It doesn't work as expected when alternating between the 2 motions.
#
# Make some tests with bulleted lists whose 1st line is prefixed by `-`.
#
# Also, try to move this diagram (left, right):
#
#                            ← bottom    top →
#
#         evolution       │      ]
#         of the stack    │      ]    }
#         as parsing      │      ]    }    >
#         progresses      │      ]    }
#                         v      ]

# FIXME:
# Try to move the 1st line down, then  up. The “no“ is merged, and we can't undo
# it.   Interesting:  if  you  decrease  the level  of  indentation,  the  issue
# disappears.
#
#                                              use ~/.vim/ftdetect/test.vim
#                                              no

# TODO: Disable folding while moving text, because moving text across folds is broken.

import Catch from 'lg.vim'

var mode: string

# Interface {{{1
def movesel#move(dir: string) #{{{2
# TODO: Make work with a motion?
# E.g.: `M-x }` moves the visual selection after the next paragraph.

    if visualmode() == 'v'
        exe "norm! gv\<c-v>\e"
    endif
    mode = visualmode()

    if mode == 'V'
        if ShouldUndojoin()
            undojoin | MoveLines(dir)
        else
            MoveLines(dir)
        endif
    elseif mode == "\<c-v>"
        if ShouldUndojoin()
            undojoin | MoveBlock(dir)
        else
            MoveBlock(dir)
        endif
    endif
    norm! gv
enddef

def movesel#duplicate(dir: string) #{{{2
    # Duplicates the selected lines/block of text
    mode = mode()
    UpdateVisualMarks()

    # Safe return if unsupported
    # TODO: Make this work in visual mode
    if mode == 'v'
        # Give them back their selection
        UpdateVisualMarks()
    endif

    if mode == 'V'
        if dir == 'up' || dir == 'down'
            DuplicateLines(dir)
        else
            UpdateVisualMarks()
            echom 'Left and Right duplication not supported for lines'
        endif
    elseif mode == "\<c-v>"
        DuplicateBlock(dir)
    endif
enddef
#}}}1
# Core {{{1
def MoveLines(dir: string) #{{{2
    var line1: number
    var line2: number
    [line1, line2] = [line("'<"), line("'>")]

    if dir == 'up' #{{{
        # if  the selection  includes  the very  first line,  we  can't move  it
        # further above, but  we can still append an empty  line right after it,
        # which gives the impression it was moved above
        if line1 == 1
            append(line2, '')
        else
            sil :*m'<-2
        endif #}}}
    elseif dir == 'down' #{{{
        # if the selection includes the very last line, we can't move it further
        # down, but  we can still  append an empty  line right before  it, which
        # gives the impression it was moved below
        if line2 == line('$')
            append(line1 - 1, '')
        else
            sil :*m'>+1
        endif #}}}
    elseif dir == 'right' #{{{
        for lnum in range(line1, line2)
            var line = getline(lnum)
            if line != ''
                setline(lnum, ' ' .. line)
            endif
        endfor #}}}
    elseif dir == 'left' #{{{
        # Moving the  selection to the left  means removing a space  in front of
        # each line.  But  we don't want to  do that if a line  in the selection
        # starts with a non-whitespace.
        # Otherwise, watch what would happen:{{{
        #
        #     # before
        #     the
        #      selection
        #     ^
        #     we want this space to be preserved
        #
        #     # after
        #     the
        #     selection
        #     ^
        #     ✘
        #}}}
        if AllLinesStartWithWhitespace(line1, line2)
            for lnum in range(line1, line2)
                getline(lnum)->substitute('^\s', '', '')->setline(lnum)
            endfor
        endif
    endif #}}}
enddef

def MoveBlock(dir: string) #{{{2
    # Logic for moving  a visual block selection, this is  much more complicated
    # than lines  since I have to  be able to part  text in order to  insert the
    # incoming line.

    var ve_save = &l:ve
    try
        setl ve=all

        # While  '< is  always above  or  equal to  '>  in lnum,  the column  it
        # references could be the first or last col in the selected block
        var line1: number
        var fcol: number
        var foff: number
        var line2: number
        var lcol: number
        var loff: number
        var left_col: number
        var right_col: number
        var _: any
        [_, line1, fcol, foff] = getpos("'<")
        [_, line2, lcol, loff] = getpos("'>")
        [left_col, right_col] = sort([fcol + foff, lcol + loff], 'N')
        if &selection == 'exclusive' && fcol + foff < lcol + loff
            right_col -= 1
        endif

        if dir == 'up' #{{{
            if line1 == 1 # First lines of file
                append(0, '')
            endif
            norm! gvxkPgvkoko
            #}}}
        elseif dir == 'down' #{{{
            if line2 == line('$') # Moving down past EOF
                append('$', '')
            endif
            norm! gvxjPgvjojo
            #}}}
        elseif dir == 'right' #{{{
            var col1: number
            var col2: number
            [col1, col2] = sort([left_col, right_col], 'N')
            var old_width = (getline('.') .. '  ')
                ->matchstr('\%' .. col1 .. 'c.*\%' .. col2 .. 'c.')
                ->strchars(1)

            # Original code:
            #
            #     norm! gvxpgvlolo
            #             ^^
            # Why did we replace `xp` with `xlP`?{{{
            #
            # Try to  move a block  to the right, beyond  the end of  the lines,
            # while there  is a multibyte character  before the 1st line  of the
            # block (example: a bulleted list):
            #
            #    - hello
            #    - people
            #
            # It fails because of `xp`.
            #
            # Solution:
            #     xp → xlP
            #
            # Interesting:
            #
            # Set  've'   to  'all',   and  select   “hello“  in   a  visual
            # characterwise selection, then press `xp` (it will work):
            #
            #    - hello
            #
            # Reselect “hello“  in a  visual blockwise selection,  and press
            # `xp` (it will fail).
            # Now, reselect, and press `xlp`: it will also fail, but not because
            # it didn't move the block, but  because it moved it 1 character too
            # far.  Why?
            #}}}
            norm! gvxlPgvlolo

            # Problem:
            # Try to move the “join, delete, sort“ block to the right.
            # At one point, it misses a character (last `e` in `delete`).
            #
            #    - join
            #    - delete
            #    - sort
            #
            # Solution:
            # After reselecting  the text (`gv`),  check that the length  of the
            # block is the  same as before.  If it's shorter,  press `l` as many
            # times as necessary.

            [col1, col2] = [col("'<"), col("'>")]
            var new_width = getline('.')
                ->matchstr('\%' .. col1 .. 'c.*\%' .. col2 .. 'c.')
                ->strchars(1)
            if old_width > new_width
                exe 'norm! ' .. (old_width - new_width) .. 'l'
            endif
            #}}}
        elseif dir == 'left' #{{{
            var vcol1: number
            var vcol2: number
            [vcol1, vcol2] = sort([virtcol("'<"), virtcol("'>")], 'N')
            var old_width = (getline('.') .. '  ')
                ->matchstr('\%' .. vcol1 .. 'v.*\%' .. vcol2 .. 'v.')
                ->strchars(1)
            if left_col == 1
                exe "norm! gvA \e"
                if getline(line1, line2)->match('^\s') != -1
                    for lnum in range(line1, line2)
                        if getline(lnum)->match('^\s') != -1
                            getline(lnum)->substitute('^\s', '', '')->setline(lnum)
                            exe 'norm! ' .. lnum .. 'G' .. right_col .. "|a \e"
                        endif
                    endfor
                endif
                UpdateVisualMarks()
            else
                norm! gvxhPgvhoho
            endif
            # Problem:
            # Select “join“ and “delete“, then press `xhPgv`, it works.
            #
            #         -join
            #         -delete
            #
            # Now, repeat  the same commands;  this time, it will  fail, because
            # `gv` doesn't reselect the right area:
            #
            #         -join
            #         -delete
            #
            # As soon as the visual  selection cross the multibyte character, it
            # loses some characters.
            #
            # Solution:
            # After reselecting  the text (`gv`),  check that the length  of the
            # block is the  same as before.  If it's shorter,  press `h` as many
            # times as necessary.
            #
            # FIXME:
            # Try to move “join, delete, sort“ to the left:
            #     gvxhPgvhoho
            #
            #    - join
            #    - delete
            #    - sort

            var col1: number
            var col2: number
            [col1, col2] = [col("'<"), col("'>")]
            var new_width = getline('.')
                ->matchstr('\%' .. col1 .. 'c.*\%' .. col2 .. 'c.')
                ->strchars(1)
            if old_width > new_width
                exe 'norm! o' .. (old_width - new_width) .. 'ho'
            endif
        endif #}}}

        # Strip Whitespace
        # Need new positions since the visual area has moved
        [_, line1, fcol, foff] = getpos("'<")
        [_, line2, lcol, loff] = getpos("'>")
        [left_col, right_col] = sort([fcol + foff, lcol + loff], 'N')
        if &selection == 'exclusive' && fcol + foff < lcol + loff
            right_col -= 1
        endif
        for lnum in range(line1, line2)
            getline(lnum)->substitute('\s\+$', '', '')->setline(lnum)
        endfor
        # Take care of trailing space created on lines above or below while
        # moving past them
        if dir == 'up'
            getline(line2 + 1)->substitute('\s\+$', '', '')->setline(line2 + 1)
        elseif dir == 'down'
            getline(line1 - 1)->substitute('\s\+$', '', '')->setline(line1 - 1)
        endif
    catch
        Catch()
    finally
        &l:ve = ve_save
    endtry
enddef

def DuplicateLines(dir: string) #{{{2
    var reselect: string
    if dir == 'up'
        reselect = 'gv'
    elseif dir == 'down'
        reselect = "'[V']"
    else
        UpdateVisualMarks()
        return
    endif

    exe 'norm! gvyP' .. reselect
enddef

def DuplicateBlock(dir: string) #{{{2
    var ve_save = &l:ve
    try
        setl ve=all
        var line1: number
        var fcol: number
        var foff: number
        var line2: number
        var lcol: number
        var loff: number
        var left_col: number
        var right_col: number
        var _: any
        [_, line1, fcol, foff] = getpos("'<")
        [_, line2, lcol, loff] = getpos("'>")
        [left_col, right_col] = sort([fcol + foff, lcol + loff], {i, j -> i - j})
        if &selection == 'exclusive' && fcol + foff < lcol + loff
            right_col -= 1
        endif
        var numlines = (line2 - line1) + 1
        var numcols = (right_col - left_col)

        if dir == 'up' #{{{
            if (line1 - numlines) < 1
                # Insert enough lines to duplicate above
                for i in range((numlines - line1) + 1)
                    append(0, '')
                endfor
                # Position of selection has changed
                [_, line1, fcol, foff] = getpos("'<")
            endif

            var set_cursor = "\<cmd>call getpos(\"'<\")[1:3]->cursor()\r" .. numlines .. 'k'
            exe 'norm! gvy' .. set_cursor .. 'Pgv' #}}}
        elseif dir == 'down' #{{{
            if line2 + numlines >= line('$')
                for i in ((line2 + numlines) - line('$'))->range()
                    append('$', '')
                endfor
            endif
            exe "norm! gvy'>j" .. left_col .. '|Pgv' #}}}
        elseif dir == 'left' #{{{
            if numcols > 0
                exe 'norm! gvyP' .. numcols .. "l\<c-v>"
                    .. (numcols + (&selection == 'exclusive' ? 1 : 0)) .. 'l'
                    .. (numlines - 1) .. 'jo'
            else
                exe "norm! gvyP\<c-v>" .. (numlines - 1) .. 'jo'
            endif #}}}
        elseif dir == 'right' #{{{
            norm! gvyPgv
        else
            UpdateVisualMarks()
        endif #}}}
    catch
        Catch()
    finally
        &l:ve = ve_save
    endtry
enddef
#}}}1
# Util {{{1
def UpdateVisualMarks() #{{{2
    exe "norm! \egv"
enddef

def ShouldUndojoin(): bool #{{{2
    # We are on the last change.{{{
    #
    # We haven't played with `u`, `C-r`, `g+`, `g-`.
    # Or if we have, we've come back to the latest change.
    #}}}
    if changenr() == undotree().seq_last
    # we haven't performed more than 1 change since the last time
    && get(b:, '_movesel_state', {})->get('seq_last') == (changenr() - 1)
    # we haven't changed the type of the visual mode
    && get(b:, '_movesel_state', {})->get('mode_last') == mode
        return true
    endif

    b:_movesel_state = {mode_last: mode, seq_last: undotree().seq_last}
    return false
enddef

def AllLinesStartWithWhitespace(line1: number, line2: number): bool #{{{2
    return getline(line1, line2)->match('^\S') == -1
enddef

