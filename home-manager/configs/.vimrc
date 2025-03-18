" General settings
set number
set hidden
set mouse=a
set showcmd
set wildmenu
set wildmode=longest:full,full
set termguicolors
set ignorecase
set smartcase
set incsearch
set hlsearch
set clipboard+=unnamed,unnamedplus
set breakindent
set completeopt=menuone,noinsert,noselect
set pumheight=10
set shortmess+=c
set spelllang=en
set encoding=utf-8
set fileencoding=utf-8
set fileformat=unix
set scrolloff=5
set expandtab
set tabstop=2
set shiftwidth=2
set nowritebackup
set noswapfile
set splitbelow
set splitright

" Key bindings
inoremap jj <ESC>
inoremap jk <ESC>:w<CR>
nnoremap j gj
nnoremap k gk
nnoremap <CR> :nohlsearch<CR>
