function! vimqq#indexing#basic#run(root, index_file)
    let idx = {}

    let idx.to_count = vimqq#queue#new()
    let idx.to_summarize = vimqq#queue#new()
    let idx.data = {}
    let idx.index_file = a:index_file
    let idx.root = a:root
    if filereadable(a:index_file)
        let idx.index_file = json_decode(join(readfile(a:index_file), ''))
    endif
    
    function! idx.on_file(file_path) dict
        let full_path = self.root . '/' . a:file_path
        if filereadable(full_path)
            let checksum = vimqq#platform#checksum#sha256(full_path)
            let d = get(self.data, a:file_path, {})
            if get(d, 'checksum', '') ==# checksum
                " already enqueued it
                return
            endif
            let d['checksum'] = checksum
            let self.data[a:file_path] = d
            call self.to_count.enqueue(a:file_path)
        else
            call vimqq#log#warning('unable to read file ' . a:file_path)
        endif
    endfunction

    function! idx.on_counted(file_path, token_count) dict
        call vimqq#log#debug('TC for ' . a:file_path . ' = ' . a:token_count)
        if !has_key(self.data, a:file_path)
            call vimqq#log#error('Got token count for non-enqueued file')
            return
        endif
        let self.data[a:file_path]['token_count'] = a:token_count
        call self.to_summarize.enqueue(a:file_path)
    endfunction

    function! idx.on_summary(file_path, summary) dict
        call vimqq#log#debug('summary for ' . a:file_path . ' = ' . a:summary)
        if !has_key(self.data, a:file_path)
            call vimqq#log#error('Got summary for non-enqueued file')
            return
        endif
        let self.data[a:file_path]['summary'] = a:summary
        " TODO: this is bad for large repos
        call writefile([json_encode(self.data)], a:index_file)
    endfunction

    let idx.crawler = vimqq#indexing#git#start(a:root, {f -> idx.on_file(f)})
    let idx.counter = vimqq#indexing#token_counter#start(a:root, idx.to_count, {f, c -> idx.on_counted(f, c)})
    let idx.summarizer = vimqq#indexing#summary#start(a:root, idx.to_summarize, {f, s -> idx.on_summary(f, s)})

    let g:vimqq_indexer_basic = idx

endfunction
