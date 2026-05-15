" ============================================================
"  .vimrc — Beginner Friendly, No Nonsense
"  Drop this in your home directory: ~/.vimrc
" ============================================================


" ── Core Sanity ─────────────────────────────────────────────
set nocompatible              " Ditch vi compatibility. Always.
filetype plugin indent on     " Smart filetype detection
syntax on                     " Syntax highlighting


" ── Appearance ──────────────────────────────────────────────
set number                    " Line numbers
set relativenumber            " Relative numbers (great for jumps: 5j, 12k)
set cursorline                " Highlight current line
set scrolloff=8               " Keep 8 lines visible above/below cursor
set colorcolumn=100           " Soft ruler at 100 chars
set signcolumn=yes            " Always show sign column (no layout jumps)
set termguicolors             " True color support
colorscheme desert            " Desert color scheme

" ── Indentation ─────────────────────────────────────────────
set tabstop=4                 " Tab = 4 spaces wide
set shiftwidth=4              " Indent = 4 spaces
set expandtab                 " Use spaces, not tabs
set smartindent               " Context-aware auto indent


" ── Search ──────────────────────────────────────────────────
set incsearch                 " Search as you type
set hlsearch                  " Highlight all matches
set ignorecase                " Case-insensitive search...
set smartcase                 " ...unless you type a capital

" Clear search highlights with Escape
nnoremap <Esc> :nohlsearch<CR>


" ── Behaviour ───────────────────────────────────────────────
set hidden                    " Switch buffers without saving
set nowrap                    " No line wrapping
set mouse=a                   " Mouse support (ease into it)
set clipboard=unnamedplus     " System clipboard (needs +clipboard build)
set undofile                  " Persistent undo across sessions
set undodir=~/.vim/undodir    " Where to store undo history
set updatetime=250            " Faster swap write / plugin response
set timeoutlen=500            " Faster key sequence timeout


" ── Splits ──────────────────────────────────────────────────
set splitright                " Vertical splits open to the right
set splitbelow                " Horizontal splits open below


" ── Leader Key ──────────────────────────────────────────────
let mapleader = " "           " Space as leader — most popular choice


" ── Key Maps ────────────────────────────────────────────────

" Better window navigation (no more Ctrl-W prefix)
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Move lines up/down in visual mode
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Keep cursor centred when jumping / searching
nnoremap n nzzzv
nnoremap N Nzzzv
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Quick save & quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Yank to end of line (consistent with D and C)
nnoremap Y y$

" Paste without losing the register
xnoremap <leader>p "_dP

" Open netrw file explorer
nnoremap <leader>e :Ex<CR>


" ── Netrw (built-in file explorer) ──────────────────────────
let g:netrw_banner    = 0     " Hide the banner
let g:netrw_liststyle = 3     " Tree view


" ── Auto-create undodir if missing ──────────────────────────
if !isdirectory($HOME . '/.vim/undodir')
    call mkdir($HOME . '/.vim/undodir', 'p')
endif


" ── Status Line (no plugins needed) ─────────────────────────
set laststatus=2
set statusline=\ %f           " File path
set statusline+=\ %m          " Modified flag
set statusline+=%=            " Right align
set statusline+=\ %y          " Filetype
set statusline+=\ %l:%c\      " Line:Column


" ============================================================
"  That's it. Seriously. Master this before adding more.
"
"  Next steps when you're ready:
"    - vim-plug  → plugin manager
"    - gruvbox / catppuccin → colorscheme
"    - telescope.nvim → fuzzy finder (if you move to Neovim)
" ============================================================
