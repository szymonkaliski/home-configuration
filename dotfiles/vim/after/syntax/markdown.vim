" - list text @tag and more text
" - list text @tag(some context) and more text
syntax match markdownTag /\ @\S\+/              containedin=mkdListItemLine
syntax match markdownTag /\ @\S\+(\([^)]*\))\?/ containedin=mkdListItemLine

" text @tag and more text
" text @tag(some context) and more text
syntax match markdownTag /\ @\S\+/              containedin=mkdNonListItemBlock
syntax match markdownTag /\ @\S\+(\([^)]*\))\?/ containedin=mkdNonListItemBlock

" @tag can start a line
" @tag(some context) can start a line
syntax match markdownTag /^@\S\+/              containedin=mkdNonListItemBlock
syntax match markdownTag /^@\S\+(\([^)]*\))\?/ containedin=mkdNonListItemBlock

" @review
syntax match markdownTagReview /\ @review/ containedin=markdownTag

" - list item @due(today-date)
execute "syntax match markdownTagDueToday '\ @due(" . strftime('%Y-%m-%d') . ")' containedin=mkdListItemLine"

" - [ ] checkboxes
syntax match markdownListItemDone /^\s*-\ \[x\]\ .*$/
syntax match markdownUnchecked    "\[ \]" containedin=mkdListItemLine
syntax match markdownChecked      "\[x\]" containedin=mkdListItemLine

" ~~strikethrough~~
syntax region markdownStrikethrough start="\S\@<=\~\~\|\~\~\S\@=" end="\S\@<=\~\~\|\~\~\S\@=" keepend containedin=ALL
syntax match markdownStrikethroughLines "\~\~" conceal containedin=markdownStrikethrough

highlight def link markdownStrikethroughLines Comment
highlight def link markdownStrikethrough      Comment

