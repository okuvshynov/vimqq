if exists('g:autoloaded_vimqq_fzf')
    finish
endif

let g:autoloaded_vimqq_fzf = 1

" FuzzyFinder integration
"
function! vimqq#fzf#format(chat) abort
    " Format: "title\x1fcontent\x1fid"
    " \x1f is a field separator that's unlikely to appear in content
    let content = vimqq#fmt#one(a:chat.messages[0]).content
    return a:chat.title . "\x1f" . content . "\x1f" . a:chat.id
endfunction

function! vimqq#fzf#parse(selected) abort
    " Parse the selected line back into components
    let parts = split(a:selected, "\x1f")
    return {
        \ 'title': parts[0],
        \ 'content': parts[1],
        \ 'id': parts[2]
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
        echomsg a:selected_chat
        let chat = vimqq#fzf#parse(a:selected_chat)
        call vimqq#main#show_chat(chat.id)
    endfunction
    
    " FZF options
    let opts = {
        \ 'source': formatted_chats,
        \ 'sink': function('OpenChat'),
        \ 'options': [
            \ '--delimiter=\x1f',
            \ '--with-nth=1',
            \ '--preview', 'echo -e "{}"| awk -F"\x1f" "{print $2}"',
            \ '--preview-window=right:50%',
            \ '--bind', 'ctrl-/:toggle-preview',
            \ '--multi', 0,
        \ ]
    \ }
    
    " Launch FZF
    call fzf#run(fzf#wrap(opts))
endfunction
