" General settings
set number
set hlsearch
set ignorecase   " デフォルトで大文字・小文字を無視
set smartcase    " 大文字が含まれる場合は大文字・小文字を区別
set scrolloff=5
set expandtab
set tabstop=2
set shiftwidth=2
set expandtab
set clipboard+=unnamed,unnamedplus

" Key bindings
inoremap jj <ESC>
inoremap jk <ESC>:w<CR>
nnoremap j gj
nnoremap k gk
nnoremap <CR> :nohlsearch<CR>
