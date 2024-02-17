function! abbrevs#eat_char(pat)
  let l:c = nr2char(getchar(0))
  return (l:c =~ a:pat) ? '' : l:c
endfunction

function! abbrevs#spaceless_iabbrev(from, to)
  exe 'iabbrev <silent> <buffer> ' . a:from . ' ' . a:to . '<c-r>=abbrevs#eat_char("\\s")<cr>'
endfunction
