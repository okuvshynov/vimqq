" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_token')
    finish
endif

let g:autoloaded_vimqq_indexing_token = 1

let s:PERIOD_MS = 200
let s:RETRY_PERIOD_MS = 5000

function! vimqq#indexing#token_counter#start(git_root, in_queue, OnCounted) abort
    let counter = {
        \ 'git_root' : a:git_root,
        \ 'in_queue' : a:in_queue,
        \ 'on_counted' : a:OnCounted
    \ }

    let counter.bot = vimqq#bots#llama_cpp_indexer#new({'addr' : g:vqq_indexer_addr})

    function! counter.next() dict
        let file_path = self.in_queue.dequeue()
        if file_path is v:null
            call vimqq#log#debug('No files to count tokens for')
            return self.schedule(s:RETRY_PERIOD_MS)
        endif
        let full_path = self.git_root . '/' . file_path
        
        " Skip if file doesn't exist
        if !filereadable(full_path)
            call vimqq#log#warning('Skipping non-existent file: ' . file_path)
            return self.schedule(s:PERIOD_MS)
        endif

        call vimqq#log#info('Counting tokens for ' . file_path)
        
        " Read file content
        let file_content = join(readfile(full_path), "\n")
        
        " Create request object for token count
        let req = {
            \ 'content': file_content,
            \ 'on_complete': {tokens -> self.on_token_count_complete(file_path, tokens)}
        \ }
        
        " Request token count from the bot
        call self.bot.count_tokens(req)
    endfunction
    
    " Define callback for token count result
    function! counter.on_token_count_complete(file_path, token_count) dict
        call vimqq#log#info('on_token_count_complete' . a:file_path)
        call self.schedule(s:PERIOD_MS)
        call self.on_counted(a:file_path, a:token_count)
    endfunction

    function! counter.schedule(period_ms) dict
        call timer_start(a:period_ms, {t -> self.next()})
    endfunction

    call counter.next()

    return counter
endfunction
