let s:RETRY_IN_MS = 30000
let s:INDEX_NAME  = 'basic.idx'

" It's a very limited index with no cleanup of old entries 
" and incorrect dedup. It processes one file at a time.
function! vimqq#indexing#basic#run()
    let idx = {}

    let idx.to_count     = vimqq#queue#new()
    let idx.to_summarize = vimqq#queue#new()
    let idx.root = vimqq#indexing#io#root()
    if idx.root is v:null
        call vimqq#log#warning('No indexing configured. Retry in ' . s:RETRY_IN_MS . 'ms')
        call timer_start(s:RETRY_IN_MS, {t -> vimqq#indexing#basic#run()})
        return
    endif

    let idx.ignores = vimqq#indexing#io#ignores()
    call vimqq#log#info('Ingoring patterns: ' . string(idx.ignores))

    let idx.data = vimqq#indexing#io#read(s:INDEX_NAME)
    
    function! idx.on_file(file_path) dict
        if vimqq#util#path_matches_patterns(a:file_path, self.ignores)
            return
        endif
        let full_path = self.root . '/' . a:file_path
        if filereadable(full_path)
            let checksum = vimqq#platform#checksum#sha256(full_path)
            let file_data = get(self.data, a:file_path, {})
            " TODO: this is incorrect, we need to handle it better.
            if get(file_data, 'checksum', '') ==# checksum
                " already enqueued it
                return
            endif
            let file_data['checksum'] = checksum
            let self.data[a:file_path] = file_data
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
        call vimqq#log#debug('summary for ' . a:file_path)
        if !has_key(self.data, a:file_path)
            call vimqq#log#error('Got summary for non-enqueued file')
            return
        endif
        if a:summary is v:null
            call vimqq#log#error('Error summarizing ' . a:file_path)
            return
        endif

        let self.data[a:file_path]['summary'] = a:summary
        call vimqq#log#info('Updating index file ' . s:INDEX_NAME . '. Size = ' . len(self.data))
        call vimqq#log#debug('Summarization queue size = ' . self.to_summarize.size())
        call vimqq#indexing#io#write(s:INDEX_NAME, self.data)
    endfunction

    let idx.crawler = vimqq#indexing#git#start(idx.root, {f -> idx.on_file(f)})
    let idx.counter = vimqq#indexing#token_counter#start(idx.root, idx.to_count, {f, c -> idx.on_counted(f, c)})
    let idx.summarizer = vimqq#indexing#summary#start(idx.root, idx.to_summarize, {f, s -> idx.on_summary(f, s)})

    let g:vimqq_indexer_basic = idx
endfunction

function! vimqq#indexing#basic#format()
    let data = vimqq#indexing#io#read(s:INDEX_NAME)
    if data is v:null
        call vimqq#log#error('Unable to locate index file ' . s:INDEX_NAME)
        return "Index not found"
    endif
    let res = []
    for [file_path, entry] in items(data)
        call add(res, file_path)
        call add(res, get(entry, 'summary', ''))
        call add(res, '')
    endfor
    return join(res, "\n")
endfunction
