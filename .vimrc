set number
set relativenumber
set tabstop=4

colorscheme murphy 

if has('syntax')
  syntax on
endif

set showcmd
set cursorline

if has('filetype')
  filetype indent plugin on
endif

if has('mouse')
  set mouse=a
endif


set wildmenu
set lazyredraw
set showmatch
set incsearch
set hlsearch
set foldenable
set foldlevelstart=10
nnoremap <space> za
set foldmethod=indent
set ignorecase
set smartcase
set backspace=indent,eol,start
set autoindent
set nostartofline
set ruler
set laststatus=2
set confirm
set visualbell
set t_vb=
set pastetoggle=<F11>
set notimeout ttimeout ttimeoutlen=200
set shiftwidth=4
set softtabstop=4
set expandtab
map Y y$
set cmdheight=2
nnoremap <C-L> :nohl<CR><C-L>
set wrap
set encoding=utf-8
set smartindent 
set autoread
set cursorline
