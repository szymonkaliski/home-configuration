let s:all_directories = '~/Documents/Dropbox/Wiki ~/Documents/Projects ~/Documents/Talks ~/Documents/Teaching ~/Documents/Work'
let s:rg_cmd = 'rg --smart-case --max-filesize 1M -H --no-heading --vimgrep --sort-files $* '

let g:grepper = {}
let g:grepper.highlight = 1
let g:grepper.prompt = 0
let g:grepper.stop = 1000
let g:grepper.tools = [ 'rg', 'rg-all', 'git', 'grep' ]

" sort-files is a (hopefully temporary) hack: https://github.com/mhinz/vim-grepper/issues/244
let g:grepper.rg = {
      \ 'grepprg':     s:rg_cmd . '.',
      \ 'grepformat': '%f:%l:%c:%m',
      \ 'escape':     '\^$.*+?()[]{}|'
      \ }

let g:grepper['rg-all'] = {
      \ 'grepprg':    s:rg_cmd . s:all_directories,
      \ 'grepformat': '%f:%l:%c:%m',
      \ 'escape':     '\^$.*+?()[]{}|'
      \ }

" grep from commandline
command! -nargs=+ Grep :GrepperRg <q-args>

" [g]rep
nnoremap <leader>g :Grep<space>
xmap     <leader>g <plug>(GrepperOperator)

" [g]o [l]ook (everything else is taken)
nmap gl <plug>(GrepperOperator)
xmap gl <plug>(GrepperOperator)

