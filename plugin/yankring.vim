" yankring.vim - Yank Ring for Vim
" ---------------------------------------------------------------


let s:yr_history_v2_nl     = "\2" " Use double quotes for a special character
let s:yr_history_v2_nl_pat = "\2"
let s:yr_history_list      = []
let s:yr_history_last_upd  = 0
let s:yr_count             = 0


function! s:YRHistoryRead()
    let refresh_needed  = 1

    if filereadable(g:yankring_fileame)
        let last_upd = getftime(g:yankring_fileame)

        if s:yr_history_last_upd != 0 && last_upd <= s:yr_history_last_upd
            let refresh_needed = 0
        endif

        if refresh_needed == 1
            let s:yr_history_list = readfile(g:yankring_fileame)
            let s:yr_history_last_upd = last_upd
            let s:yr_count = len(s:yr_history_list)
            return
        else
            return
        endif
    endif
endfunction

function! s:YRHistorySave()
    if len(s:yr_history_list) > g:yankring_max_history
        " Remove items which exceed the max # specified
        call remove(s:yr_history_list, g:yankring_max_history, (len(s:yr_history_list)-1))
        let s:yr_count = len(s:yr_history_list)
    endif

    let rc = writefile(s:yr_history_list, g:yankring_fileame)

    if rc == 0
        let s:yr_history_last_upd = getftime(g:yankring_fileame)
    else
        echomsg 'Unable to save yankring history file '.g:yankring_fileame
    endif
endfunction

function! YRRecord()
    let register = '"'
    let element = getreg(register)
    let element_type = getregtype(register)

    let elem = substitute(element, "\n", s:yr_history_v2_nl, 'g').",".element_type

    " Refresh the List
    call s:YRHistoryRead()

    let found = index(s:yr_history_list, elem)

    " Special case for efficiency, if it is first item in the
    " List, do nothing
    if found != 0
        if found != -1
            " Remove found item since we will add it to the top
            call remove(s:yr_history_list, found)
        endif
        call insert(s:yr_history_list, elem, 0)
        let s:yr_count = len(s:yr_history_list)
        call s:YRHistorySave()
    endif

    " Reset the past paste entry to the top of the ring.
    " When the user hits replace last entry it should
    " start from the top (not from the last previous
    " replace) after capturing a new value in the YankRing.
    let s:yr_last_paste_idx = 1
    return
endfunction

" Paste from either the yankring or from a specified register
function! s:YRPaste(replace_last_paste_selection, nextvalue, direction)
    let default_register = '"'

    if a:replace_last_paste_selection == 1
        " Replacing the previous put
        let start = line("'[")
        let end = line("']")

        if start != line('.')
            echomsg 'YR: You must paste text first, before you can replace'
            return
        endif

        if start == 0 || end == 0
            return
        endif

        let which_elem = matchstr(a:nextvalue, '-\?\d\+') * -1
        let s:yr_last_paste_idx = s:YRGetNextElem(s:yr_last_paste_idx, which_elem)

        let save_reg            = getreg(default_register)
        let save_reg_type       = getregtype(default_register)
        call setreg( default_register
                    \ , s:YRGetValElemNbr((s:yr_last_paste_idx-1),'v')
                    \ , s:YRGetValElemNbr((s:yr_last_paste_idx-1),'t')
                    \ )

        " First undo the previous paste
        exec "normal! u"
        " Check if the visual selection should be reselected
        " Next paste the correct item from the ring
        " This is done as separate statements since it appeared that if
        " there was nothing to undo, the paste never happened.
        exec "normal! ".'"'.default_register.s:yr_paste_dir
        call setreg(default_register, save_reg, save_reg_type)
    else
        " Read history file again first so that get the up-to-date yanks by other vim instances
        call s:YRHistoryRead()
        let save_reg            = getreg(default_register)
        let save_reg_type       = getregtype(default_register)
        let s:yr_last_paste_idx = 1
        call setreg(default_register, s:YRGetValElemNbr(0,'v'), s:YRGetValElemNbr(0,'t'))
        exec "normal! ".'"'.default_register.a:direction
        call setreg(default_register, save_reg, save_reg_type)
        let s:yr_paste_dir     = a:direction
    endif

endfunction

" This internal function will add and subtract values from a starting
" point and return the correct element number.  It takes into account
" the circular nature of the yankring.
function! s:YRGetNextElem(start, iter)
    let needed_elem = a:start + a:iter

    " The yankring is a ring, so if an element is
    " requested beyond the number of elements, we
    " must wrap around the ring.
    if needed_elem > s:yr_count
        let needed_elem = needed_elem % s:yr_count
    endif

    if needed_elem == 0
        " Can happen at the end or beginning of the ring
        if a:iter == -1
            " Wrap to the bottom of the ring
            let needed_elem = s:yr_count
        else
            " Wrap to the top of the ring
            let needed_elem = 1
        endif
    elseif needed_elem < 1
        " As we step backwards through the ring we could ask for a negative
        " value, this will wrap it around to the end
        let needed_elem = s:yr_count
    endif

    return needed_elem
endfunction

function! s:YRGetValElemNbr( position, type )
    let needed_elem = a:position

    " The List which contains the items in the yankring
    " history is also ordered, most recent at the top
    let elem = get(s:yr_history_list, needed_elem, -2)

    if a:type == 't'
        let elem = matchstr(elem, '^.*,\zs.*$')
    else
        let elem = matchstr(elem, '^.*\ze,.*$')
        let elem = substitute(elem, s:yr_history_v2_nl_pat, "\n", 'g')
    endif

    return elem
endfunction

" Handles ranges.  There are visual ranges and command line ranges.
" Visual ranges are easy, since we pass through and let Vim deal
" with those directly.
" Command line ranges means we must yank the entire line, and not
" just a portion of it.
function! s:YRYankRange(...) range
    " In normal mode, always yank the complete line, since this
    " command is for a range.  YRYankCount is used for parts
    " of a single line
    exec a:firstline . ',' . a:lastline . 'y'
    call YRRecord()
endfunction


if g:yankring_paste_n_bkey != ''
    exec 'nnoremap <silent>'.g:yankring_paste_n_bkey." :<C-U>YRPaste 'P'<CR>"
endif

if g:yankring_paste_n_bkey != ''
    exec 'nnoremap <silent>'.g:yankring_paste_n_akey." :<C-U>YRPaste 'p'<CR>"
endif

if g:yankring_replace_n_pkey != ''
    exec 'nnoremap <silent>'.g:yankring_replace_n_pkey." :<C-U>YRReplace '-1', P<CR>"
endif

if g:yankring_replace_n_nkey != ''
    exec 'nnoremap <silent>'.g:yankring_replace_n_nkey." :<C-U>YRReplace '1', p<CR>"
endif

if g:yankring_v_key != ''
    exec 'vnoremap <silent>'.g:yankring_v_key." :YRYankRange 'v'<CR>"
endif


" Public commands
command! -count -register -nargs=* YRPaste          call s:YRPaste(0,1,<args>)
command!                  -nargs=* YRReplace        call s:YRPaste(1,<f-args>)
command! -range           -nargs=? YRYankRange      <line1>,<line2>call s:YRYankRange(<args>)


