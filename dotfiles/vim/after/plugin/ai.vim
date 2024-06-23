let g:vim_ai_token_file_path = '~/.vim-openai-key'

" https://platform.openai.com/docs/models
let s:chat_ai_model = "gpt-4o"
let s:instruct_ai_model = "gpt-4o"

let s:edit_initial_prompt =<< trim END
>>> system

You are a text and code editing engine.
You will be sent an instruction, followed by a colon and then a chunk of text.
You will return code or text that will be directy inserted into a file.
Your response will be directy insersted in place of the chunk you have been sent.
Do not give any commentary about the text.
If you are returning code, do not place it in code blocks, instead just return the code as plain text.
END

let g:vim_ai_chat = {
  \  'options': {
  \    'model': s:chat_ai_model,
  \    'role_prefix': '#'
  \  },
  \  'ui': {
  \    'code_syntax_enabled': 1,
  \    'open_chat_command': 'vnew | call vim_ai#MakeScratchWindow()"',
  \    'populate_options': 0,
  \    'scratch_buffer_keep_open': 1,
  \  },
  \}

let g:vim_ai_edit = {
  \  'engine': 'chat',
  \  'options': {
  \    'endpoint_url': "https://api.openai.com/v1/chat/completions",
  \    'initial_prompt': s:edit_initial_prompt,
  \    'model': s:instruct_ai_model,
  \    'selection_boundary': '',
  \  }
  \}

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

function! s:DoChat(mode)
  if a:mode == "v"
    :call <sid>YankWithCodeBlock()
    :AIChat
    normal! p
  elseif a:mode == "n"
    :AIChat
  endif
endfunction

nnoremap <leader>ar :AIRedo<cr>

nnoremap <leader>at :AIEdit implement the TODO and FIXME comments<cr>
vnoremap <leader>at :AIEdit implement the TODO and FIXME comments<cr>

nnoremap <leader>as :AIEdit fix spelling and grammar<cr>
vnoremap <leader>as :AIEdit fix spelling and grammar<cr>

nnoremap <leader>ae :AIEdit
vnoremap <leader>ae :AIEdit

nnoremap <leader>aa :call <sid>DoChat("n")<cr>
vnoremap <leader>aa :<C-u>call <sid>DoChat("v")<cr>

augroup ai_plugin
  au!

  au BufRead,BufNewFile *.aichat set filetype=aichat
  au FileType aichat setlocal filetype=markdown
augroup END
