" Global variables to store buffer numbers
let s:history_buf = -1
let s:input_buf = -1

" Set up the split windows
function! SetupChatWindow()
    " Create a new buffer for chat input
    new
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    let s:input_buf = bufnr('%')
    
    " Set custom statusline for input window
    setlocal statusline=Chat\ Input

    " Create a new buffer for chat history
    new
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nobuflisted
    let s:history_buf = bufnr('%')
    
    " Set custom statusline for history window
    setlocal statusline=Chat\ History

    " Adjust window sizes
    let total_height = winheight(0) + winheight(winnr('#'))
    let input_height = 5
    let history_height = total_height - input_height

    " Resize windows
    execute 'resize ' . history_height
    wincmd j
    execute 'resize ' . input_height

    " Focus on the input window and enter insert mode
    call FocusInputWindow()
endfunction

" Function to focus on input window
function! FocusInputWindow()
    let input_win = bufwinnr(s:input_buf)
    if input_win != -1
        execute input_win . 'wincmd w'
        startinsert
    endif
endfunction

" Send message function
function! SendMessage()
    " Get the message from the input buffer
    let message = getbufline(s:input_buf, 1, '$')
    
    " Append the message to the history buffer
    call win_execute(bufwinid(s:history_buf), 'setlocal noreadonly')
    call appendbufline(s:history_buf, '$', 'You: ' . join(message, "\n"))
    call win_execute(bufwinid(s:history_buf), 'setlocal readonly')
    
    " Clear the input buffer
    call deletebufline(s:input_buf, 1, '$')
    
    " Here you would typically send the message to your chat backend
    " and then update the history with the response
    
    " For demonstration, let's just echo a response
    call win_execute(bufwinid(s:history_buf), 'setlocal noreadonly')
    call appendbufline(s:history_buf, '$', 'Bot: Thanks for your message!')
    call win_execute(bufwinid(s:history_buf), 'setlocal readonly')
    
    " Scroll the history window to the bottom
    call win_execute(bufwinid(s:history_buf), 'normal! G')
    
    " Move cursor back to input window and enter insert mode
    call FocusInputWindow()
endfunction

" Set up key mappings
nnoremap <Leader>c :call SetupChatWindow()<CR>
nnoremap <Leader>s :call SendMessage()<CR>
