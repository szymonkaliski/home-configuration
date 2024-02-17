" open url in browser on OSX
function! utils#open_url(visual)
  let l:url = ''

  if a:visual
    let [l:lnum1, l:col1] = getpos("'<")[1:2]
    let [l:lnum2, l:col2] = getpos("'>")[1:2]
    let l:lines = getline(l:lnum1, l:lnum2)
    let l:lines[-1] = l:lines[-1][: l:col2 - (&selection == 'inclusive' ? 1 : 2)]
    let l:lines[0] = l:lines[0][l:col1 - 1:]

    let l:url = join(l:lines, '\n')
  else
    " let l:url = matchstr(getline('.'), '[a-z]*:\/\/[^ >,;]*')
    let l:url = matchstr(getline('.'), '\v[a-z]*:\/\/[^)\]''" ]+')
  endif

  if l:url != ''
    " let l:url = escape(l:url, '#%!')

    call jobstart(["open", l:url])

    echo 'Opening: ' . l:url
  else
    echo 'Can''t find URL'
  endif
endfunction

" open quicklook - usefool for images in markdown
function! utils#open_quicklook(visual)
  let l:path = ''

  if a:visual
    let [l:lnum1, l:col1] = getpos("'<")[1:2]
    let [l:lnum2, l:col2] = getpos("'>")[1:2]
    let l:lines = getline(l:lnum1, l:lnum2)
    let l:lines[-1] = l:lines[-1][: l:col2 - (&selection == 'inclusive' ? 1 : 2)]
    let l:lines[0] = l:lines[0][l:col1 - 1:]

    let l:path = join(l:lines, '\n')
  else
    let l:keyword = &iskeyword

    set iskeyword+=.
    set iskeyword+=/
    let l:path = expand('<cword>')
    exe 'set iskeyword=' . l:keyword
  endif

  if len(l:path) != 0
    call jobstart(["qlmanage", "-p", expand('%:p:h') . '/' . l:path])
  else
    call jobstart(["qlmanage", "-p", expand('%')])
  endif

  redraw!
endfunction

function! utils#format_buffer_nr(bufnr)
  let l:bufinfo  = getbufinfo(a:bufnr)[0]

  let l:filename = l:bufinfo.name
  let l:modified = l:bufinfo.changed
  let l:buftype  = getbufvar(a:bufnr, '&buftype')
  let l:filetype = getbufvar(a:bufnr, '&filetype')

  if l:filetype == 'fzf'
    return '[FZF]'
  endif

  let l:splited = split(l:filename, '/')
  let l:cut = 3

  if len(l:splited) < l:cut
    let cut = len(l:splited)
  endif

  let l:cut = -l:cut
  if len(l:splited) == 0
    if l:buftype == 'nofile'
      return '[Scratch]'
    else
      return '[No Name]'
    endif
  else
    let l:mod = l:modified ? '+' : ''
    return join(l:splited[l:cut : -1], '/') . l:mod
  endif
endfunction

" nice buffer name
function! utils#buffer_name()
  if &filetype == 'fzf'
    return '[FZF]'
  endif

  if &filetype == 'qf'
    return exists('w:quickfix_title') ? w:quickfix_title : '[Quickfix]'
  endif

  return utils#format_buffer_nr(bufnr('%'))
endfunction

" nice window name
function! utils#window_name()
  let s:app_name = has('nvim') ? 'nvim' : 'vim'
  return s:app_name . ': ' . utils#buffer_name()
endfunction

" nice statusbar right hand side
" adapted from https://github.com/wincent/wincent/blob/master/roles/dotfiles/files/.vim/autoload/wincent/statusline.vim
function! utils#statusline_right() abort
  let l:rhs=''

  let l:line=line('.')
  let l:height=line('$')
  let l:column=virtcol('.')
  let l:max_col=3

  let l:padding_line=len(l:height) - len(l:line)
  let l:padding_col=l:max_col - len(l:column)

  if l:padding_line
    let l:rhs.=repeat('0', l:padding_line)
  endif

  let l:rhs.=l:line
  let l:rhs.='/'

  if l:padding_col
    let l:rhs.=repeat('0', l:padding_col)
  endif

  let l:rhs.=l:column
  let l:rhs.=' : '
  let l:rhs.=l:height

  return l:rhs
endfunction

function! utils#statusline_ale()
  if !exists(':ALELint')
    return ''
  endif

  let l:error_symbol = 'E: '
  let l:warning_symbol = 'W: '

  let l:counts = ale#statusline#Count(bufnr(''))

  let l:output = ''

  if l:counts.error
    let l:output.=l:error_symbol
    let l:output.=l:counts.error
  endif

  if l:counts.warning
    if l:counts.error
      let l:output.=' '
    endif

    let l:output.=l:warning_symbol
    let l:output.=l:counts.warning
  endif

  return l:output
endfunction

function! utils#statusline_coc()
  let l:error_symbol = 'E: '
  let l:warning_symbol = 'W: '

  let l:counts = get(b:, 'coc_diagnostic_info', 0)
  let l:output = ''

  if l:counts.error
    let l:output.=l:error_symbol
    let l:output.=l:counts.error
  endif

  if l:counts.warning || l:counts.information
    if l:counts.error
      let l:output.=' '
    endif

    let l:output.=l:warning_symbol
    let l:output.=(l:counts.warning + l:counts.information)
  endif

  return l:output
endfunction

" reload vim settings
if !exists('*utils#reload_settings')
  function! utils#reload_settings()
    silent! source $MYVIMRC

    if has('gui') | source $MYGVIMRC | endif

    setlocal foldmethod=marker

    call lightline#update()

    echo 'Settings reloaded'
  endfunction

  command! ReloadSettings :call utils#reload_settings()
endif

" loads multiple files
function! utils#E(...)
  for f1 in a:000
    let files = glob(f1)
    if files == ''
      exe 'e ' . escape(f1, '\ "')
    else
      for f2 in split(files, "\n")
        exe 'e ' . escape(f2, '\ "')
      endfor
    endif
  endfor
endfunction

" kills trailing whitespaces
function! utils#kill_whitespace()
  let l:cursor_pos = getpos('.')
  keepjumps keeppatterns %s/\s\+$//e
  call setpos('.', l:cursor_pos)

  echo 'Whitespace cleaned'
endfunction

" shows syntax highlight group for element
function! utils#show_syntax()
  echo join(map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")'), ' > ')
endfunction

" destroy all buffers that are not open in any tabs or windows
" https://github.com/artnez/vim-wipeout/blob/master/plugin/wipeout.vim
function! utils#wipeout(bang)
  " figure out which buffers are visible in tabs
  let l:visible = {}

  for t in range(1, tabpagenr('$'))
    for b in tabpagebuflist(t)
      let l:visible[b] = 1
    endfor
  endfor

  " close buffers that are loaded and not visible
  let l:tally = 0
  let l:cmd = 'bw'

  if a:bang
    let l:cmd = l:cmd . '!'
  endif

  for b in range(1, bufnr('$'))
    if buflisted(b) && !has_key(l:visible, b)
      let l:tally += 1
      exe l:cmd . ' ' . b
    endif
  endfor

  echon 'Deleted ' . l:tally . ' buffer' . (l:tally == 1 ? '' : 's')
endfunction

" rename current file
function! utils#rename_file()
  let l:old_name = expand('%')
  let l:new_name = input('New file name: ', fnameescape(expand('%')), 'file')

  if l:new_name != '' && l:new_name != l:old_name
    exe ':saveas ' . l:new_name
    exe ':e!' . l:new_name
    exe ':silent !rm ' . l:old_name
  endif
endfunction

" remove current file
function! utils#remove_file()
  let l:choice = confirm('Delete file and close buffer?', "&Yes\n&No", 1)

  if l:choice == 1
    call delete(expand('%:p'))
    Sayonara!
    echo
  endif
endfunction

" find TODO/FIXME in code
function! utils#find_todo() abort
  let entries = []

  for cmd in [ 'git grep -n -e TODO -e FIXME 2> /dev/null', 'rg --vimgrep "(TODO|FIXME)" 2> /dev/null' ]
    let lines = split(system(cmd), '\n')
    if v:shell_error != 0 | continue | endif
    for line in lines
      let [fname, lno, text] = matchlist(line, '^\([^:]*\):\([^:]*\):\(.*\)')[1:3]
      call add(entries, { 'filename': fname, 'lnum': lno, 'text': text })
    endfor
    break
  endfor

  if !empty(entries)
    call setqflist(entries)
    copen
  endif
endfunction

" pipe given lines through shell script
function! utils#pipe_through_script(lines, script)
  let l:cli = ''

  let l:cli = l:cli . 'echo ' . shellescape(join(a:lines, '\n'))
  let l:cli = l:cli . ' | ' . a:script

  return system(l:cli)
endfunction

" zoom split pane
function! utils#zoom_split() abort
  if exists('t:zoomed') && t:zoomed
    exe t:zoom_winrestcmd
    let t:zoomed = 0
  else
    let t:zoom_winrestcmd = winrestcmd()
    resize
    vertical resize
    let t:zoomed = 1
  endif
endfunction

function! utils#markdown_edit_link(in_tab)
  let l:lnum = line('.')
  let l:col = col('.')
  let l:syn = synIDattr(synID(l:lnum, l:col, 1), 'name')
  let l:line = getline(l:lnum)
  let l:char = l:line[col - 1]

  if a:in_tab
    wincmd v
  endif

  if l:char ==# '[' || l:syn ==# 'mkdLink'
    execute "normal! f(vi(gF"
  elseif l:syn ==# 'mkdUrl'
    execute "normal! vi(gF"
  else
    execut "normal! gF"
  endif
endfunction

