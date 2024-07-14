" Set up the split windows
function! SetupChatWindow()
    " Create a new buffer for chat history
    new
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    setlocal readonly
    let s:history_buf = bufnr('%')

    " Create a new buffer for input
    new
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    let s:input_buf = bufnr('%')

    " Adjust window sizes
    execute 'resize ' . (winheight(0) - 5)
    wincmd j
    resize 5
endfunction

" Send message function
function! SendMessage()
    " Get the message from the input buffer
    let message = getbufline(s:input_buf, 1, '$')
    
    " Append the message to the history buffer
    call appendbufline(s:history_buf, '$', 'You: ' . join(message, "\n"))
    
    " Clear the input buffer
    call deletebufline(s:input_buf, 1, '$')
    
    " Here you would typically send the message to your chat backend
    " and then update the history with the response
    
    " For demonstration, let's just echo a response
    call appendbufline(s:history_buf, '$', 'Bot: Thanks for your message!')
    
    " Scroll the history window to the bottom
    call win_execute(bufwinid(s:history_buf), 'normal! G')
endfunction

" Set up key mappings
nnoremap <Leader>c :call SetupChatWindow()<CR>
nnoremap <Leader>s :call SendMessage()<CR>
