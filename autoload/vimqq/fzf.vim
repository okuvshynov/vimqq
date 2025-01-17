if exists('g:autoloaded_vimqq_fzf')
    finish
endif

let g:autoloaded_vimqq_fzf = 1

" FuzzyFinder integration
" TODO: this needs to be improved, both search and presentation

function! vimqq#fzf#fmt_msg(message) abort
    if a:message['role'] ==# 'user'
        let prompt = "You: @" . a:message['bot_name'] . " "
    else
        let prompt = a:message['bot_name'] . ": "
    endif
    if has_key(a:message, 'message')
        return prompt . a:message['message']
    endif
    return prompt
endfunction

function! vimqq#fzf#format(chat) abort
    " Format: "title\x1fcontent\x1fid"
    " \x1f is a field separator that's unlikely to appear in content
    return a:chat.title . "\x1f" . a:chat.id
endfunction

function! vimqq#fzf#parse(selected) abort
    " Parse the selected line back into components
    let parts = split(a:selected, "\x1f")
    return {
        \ 'title': parts[0],
        \ 'id': parts[1]
    \ }
endfunction

function! vimqq#fzf#show(db) abort
    " Check if fzf is available
    if !exists('*fzf#run')
        echohl ErrorMsg
        echomsg 'FZF is not installed. Please install junegunn/fzf.vim plugin first.'
        echomsg 'You can install it with your plugin manager, e.g.:'
        echomsg '  Plug ''junegunn/fzf'', { ''do'': { -> fzf#install() } }'
        echomsg '  Plug ''junegunn/fzf.vim'''
        echohl None
        return
    endif

    let chats = a:db.get_ordered_chats_with_messages()
    
    let formatted_chats = map(chats, 'vimqq#fzf#format(v:val)')

    function! OpenChat(selected_chat)
        let chat = vimqq#fzf#parse(a:selected_chat)
        call vimqq#events#notify('chat_selected', {'chat_id': chat.id})
    endfunction
    
    " FZF options
    let opts = {
        \ 'source': formatted_chats,
        \ 'sink': function('OpenChat'),
        \ 'options': [
            \ '--delimiter=\x1f',
            \ '--with-nth=1',
            \ '--preview', 'echo -e "{}"',
            \ '--preview-window=right:50%',
            \ '--bind', 'ctrl-/:toggle-preview',
            \ '--multi', 0,
        \ ]
    \ }
    
    " Launch FZF
    call fzf#run(fzf#wrap(opts))
endfunction
