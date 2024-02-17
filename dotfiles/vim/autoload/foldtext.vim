" nice fold text modified from: https://coderwall.com/p/usd_cw
function! foldtext#foldtext()
  let l:lpadding = &fdc
  redir => l:signs
    exe 'silent sign place buffer=' . bufnr('%')
  redir End
  let l:lpadding += l:signs =~ 'id=' ? 2 : 0

  if exists('+relativenumber')
    if (&number)
      let l:lpadding += max([&numberwidth, strlen(line('$'))]) + 1
    elseif (&relativenumber)
      let l:lpadding += max([&numberwidth, strlen(v:foldstart - line('w0')), strlen(line('w$') - v:foldstart), strlen(v:foldstart)]) + 1
    endif
  else
    if (&number)
      let l:lpadding += max([&numberwidth, strlen(line('$'))]) + 1
    endif
  endif

  let l:start = substitute(getline(v:foldstart), '\t', repeat(' ', &tabstop), 'g')

  " ugly patch for last line being non-blank
  " and markdown files where l:end looks wrong
  if v:foldend == line('$') || &ft == 'markdown'
    let l:end = ''
  else
    let l:end = substitute(substitute(getline(v:foldend), '\t', repeat(' ', &tabstop), 'g'), '^\s*', '', 'g')
  endif

  let l:width = winwidth(0) - l:lpadding

  let l:separator = ' ... '
  let l:separatorlen = strlen(substitute(l:separator, '.', 'x', 'g'))
  let l:start = strpart(l:start , 0, l:width - strlen(substitute(l:end, '.', 'x', 'g')) - l:separatorlen)
  let l:text = l:start . l:separator . l:end

  return l:text
endfunction
