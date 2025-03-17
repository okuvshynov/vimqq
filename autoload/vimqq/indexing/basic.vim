function! vimqq#indexing#basic#run(folder)
    let idx = {}
    let idx.crawled_queue = vimqq#queue#new()
    
    function! idx.on_file(file_path) dict
        call self.crawled_queue.enqueue(a:file_path)
    endfunction

    function! idx.on_counted(file_path, token_count) dict
        call vimqq#log#debug('TC for ' . a:file_path . ' = ' . a:token_count)
    endfunction

    let idx.crawler = vimqq#indexing#git#start(a:folder, {f -> idx.on_file(f)})
    let idx.counter = vimqq#indexing#token_counter#start(a:folder, idx.crawled_queue, {f, c -> idx.on_counted(f, c)})

    let g:vimqq_indexer_basic = idx

endfunction
