This a lite implementation of `YankRing.vim` for self use. The lite YankRing will only record the yanked contents when you visually select lines followed by the copy shortcut `,y` below.

The available config settings:
```
let g:yankring_max_history = 16
let g:yankring_fileame = $HOME.'/.vim/yankring.txt'
let g:yankring_v_key = ',y'
let g:yankring_paste_n_bkey = ',P'
let g:yankring_paste_n_akey = ',p'
let g:yankring_replace_n_nkey = '<C-n>'
let g:yankring_replace_n_pkey = '<C-p>'
```
