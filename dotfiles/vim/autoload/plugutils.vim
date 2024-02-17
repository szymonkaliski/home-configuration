" sources:
" - https://www.reddit.com/r/vim/comments/7datnj/vimplug_cursorhold_and_ondemand_loading/dpxfjym/?st=ja3oaqh0&sh=a9e76b40
" - https://github.com/junegunn/vim-plug/wiki/faq#conditional-activation

function plugutils#load()
  function! LoadAndDestroy(plugin, ...) abort
    call plug#load(a:plugin)
    execute 'autocmd! Defer_' . a:plugin

    if a:0
      execute a:1
    endif
  endfunction

  function! Defer(github_ref, ...) abort
    if !has('vim_starting')
      return
    endif

    let plug_args = a:0 ? a:1 : {}
    call extend(plug_args, { 'on': [] })
    call plug#(a:github_ref, plug_args)

    let plugin = a:github_ref[stridx(a:github_ref, '/') + 1:]
    let lad_args = '"' . plugin . '"'

    if a:0 > 1
      let lad_args .= ', "' . a:2 . '"'
    endif

    let call_loadAndDestroy = 'call LoadAndDestroy(' . lad_args . ')'

    execute 'augroup Defer_' . plugin . ' |'
          \ '  autocmd CursorHold,CursorHoldI * ' . call_loadAndDestroy . ' | '
          \ 'augroup end'
  endfunction

  command! -nargs=+ DeferPlug call Defer(<args>)

  function! Cond(cond, ...)
    let opts = get(a:000, 0, {})
    return a:cond ? opts : extend(opts, { 'on': [], 'for': [] })
  endfunction
endfunction
