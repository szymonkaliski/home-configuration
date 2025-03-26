let g:vim_ai_token_file_path = '~/.vim-openai-key'

" note that:
" - o1 doesn`t support `# >>> system` prompt, use `# >>> user` instead
" - we have to add the `# >>>` prefix, so it's parsed properly, as we assume
"   all chat messages use the same format
let s:chat_initial_prompt =<< trim END
# >>> user

You are a general assistant.
Provide compact code/text completion, generation, transformation, or explanation.
You should be concise, direct, and to the point.

You should NOT answer with unnecessary preamble or postamble (such as explaining your code or summarizing your action), unless the user asks you to.

Do not add comments to the code you write, unless the user asks you to, or the code is complex and requires additional context.
Do not modify the parts of the code that are not related to the task you're currently working on.
Keep and follow the existing code style, including naming conventions, commentary, whitespace, etc.
END

" note that:
" - o1/o3-min do support the `system` prompt, and that, at least here, `>>>`
"   works better than `# >>>` for some reason - might be that the `role_prefix` in
"   my fork of `vim-ai` is not implemented correctly everywhere
let s:edit_initial_prompt =<< trim END
>>> system

You are a text and code editing engine.
You will be sent an instruction followed by a colon and then a chunk of text.
You will return code or text that will be directly inserted into a file.
Your response will be directly inserted in place of the chunk you have been sent.

Do not give any additional commentary about what you are doing; just return the result as plain text.
Do not enclose code in markdown fencing.
Do not add comments to the code you write, unless the code is complex and requires additional context.
END

let g:vim_ai_chat = {
  \ 'options': {
  \   'model': 'o1-preview',
  \   'initial_prompt': s:chat_initial_prompt,
  \   'stream': 1,
  \   'role_prefix': '#',
  \   'request_timeout': 120,
  \ },
  \ 'ui': {
  \   'code_syntax_enabled': 1,
  \   'open_chat_command': 'vnew',
  \   'populate_options': 0,
  \   'scratch_buffer_keep_open': 1,
  \ },
  \}

let g:vim_ai_edit = {
  \ 'engine': 'chat',
  \ 'options': {
  \   'endpoint_url': "https://api.openai.com/v1/chat/completions",
  \   'model': 'o3-mini',
  \   'selection_boundary': '',
  \   'temperature': 1,
  \   'request_timeout': 20,
  \   'initial_prompt': s:edit_initial_prompt
  \ }
  \}

let g:vim_ai_open_chat_presets = {
  \ 'preset_right': 'vnew',
  \ 'preset_tab': 'enew'
  \}

" this is broken and setting it makes the AIChat just use current buffer
" let g:vim_ai_chat_scratch_buffer_name = '[AI Chat]'

function! s:YankWithCodeBlock()
  let l:filetype = &filetype
  if l:filetype == ''
    let l:filetype = 'text'
  endif
  normal! gv"zy
  let l:code = getreg('z')
  let l:formatted_code = '```' . l:filetype . "\n" . l:code . "```\n"
  call setreg('*', l:formatted_code)
  normal! ""
endfunction

function! s:DoChat(options)
  let l:opts = extend({
        \ 'mode':     'n',
        \ 'position': '/right',
        \ 'is_new':   v:true,
        \ 'prompt':   ''
        \ }, a:options)

  echom l:opts

  if l:opts.mode == 'v'
    call <sid>YankWithCodeBlock()

    if l:opts.is_new
      execute "AIChat " . l:opts.position
    else
      :AIChat
    endif

    normal! p
  elseif l:opts.mode == 'n'
    if l:opts.is_new
      execute "AIChat " . l:opts.position
    else
      :AIChat
    endif
  endif

  if !empty(l:opts.prompt)
    call setline('.', l:opts.prompt)
  endif
endfunction

" 'tab' preset is used for 'full'-screen
command! -nargs=* AIChatFull call <sid>DoChat({ "position": "/tab", "prompt": <q-args> })

nnoremap <leader>ar :AIRedo<cr>

nnoremap <leader>at :AIEdit implement the TODO and FIXME comments<cr>
vnoremap <leader>at :AIEdit implement the TODO and FIXME comments<cr>

nnoremap <leader>as :AIEdit fix spelling, grammar, and any syntax errors you can spot<cr>
vnoremap <leader>as :AIEdit fix spelling, grammar, and any syntax errors you can spot<cr>

nnoremap <leader>aa :call <sid>DoChat({ 'mode': 'n', 'is_new': v:false })<cr>
vnoremap <leader>aa :<c-u>call <sid>DoChat({ 'mode': 'v', 'is_new': v:false })<cr>

" a [n]ew
nnoremap <leader>an :call <sid>DoChat({ 'mode': 'n', 'position': '/right' })<cr>
nnoremap <leader>an :<c-u>call <sid>DoChat({ 'mode': 'v', 'position': '/right' })<cr>

" a [f]ull
nnoremap <leader>af :call <sid>DoChat({ 'mode': 'n', 'position': '/tab' })<cr>
vnoremap <leader>af :<c-u>call <sid>DoChat({ 'mode': 'v', 'position': '/tab' })<cr>

vnoremap <leader>ay :<c-u>call <sid>YankWithCodeBlock()<cr>

augroup ai_plugin
  au!

  " au BufRead,BufNewFile *.aichat setlocal filetype=aichat
  au FileType aichat setlocal filetype=markdown
augroup END

