let g:vim_ai_token_file_path = '~/.vim-openai-key'

" https://platform.openai.com/docs/models/gpt-4-and-gpt-4-turbo
let s:chat_ai_model = "gpt-4-turbo-preview"
let s:instruct_ai_model = "gpt-4-1106-preview"

let g:vim_ai_chat = {
  \  'options': {
  \    'model': s:chat_ai_model,
  \  },
  \  'ui': {
  \    'code_syntax_enabled': 1,
  \    'populate_options': 0,
  \    'open_chat_command': 'vnew | call vim_ai#MakeScratchWindow()"',
  \    'scratch_buffer_keep_open': 1,
  \  },
  \}

let g:vim_ai_complete = {
  \  'options': {
  \    'model': s:instruct_ai_model,
  \  }
  \}

let g:vim_ai_edit = {
  \  'options': {
  \    'model': s:instruct_ai_model,
  \  }
  \}

function! s:chat(mode)
  if a:mode == "v"
    normal! gvy
    :AIChat
    normal! p
  else
    :AIChat
  endif
endfunction

nnoremap <leader>a :call <sid>chat("n")<cr>
vnoremap <leader>a :<C-u>call <sid>chat("v")<cr>

