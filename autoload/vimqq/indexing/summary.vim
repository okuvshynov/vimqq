" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_summary')
    finish
endif

let g:autoloaded_vimqq_indexing_summary = 1

let s:PERIOD_MS = 200
let s:RETRY_PERIOD_MS = 5000

function! vimqq#indexing#summary#start(git_root, in_queue, OnSummary) abort
    let summ = {
        \ 'git_root' : a:git_root,
        \ 'in_queue' : a:in_queue,
        \ 'on_summary' : a:OnSummary
    \ }

    let summ.bot = vimqq#bots#llama_cpp_indexer#new({'addr' : g:vqq_indexer_addr})

    function! summ.next() dict
        let file_path = self.in_queue.dequeue()
        if file_path is v:null
            call vimqq#log#debug('No files to summarize.')
            return self.schedule(s:RETRY_PERIOD_MS)
        endif
        let full_path = self.git_root . '/' . file_path
        
        " Skip if file doesn't exist
        if !filereadable(full_path)
            call vimqq#log#warning('Skipping non-existent file: ' . file_path)
            return self.schedule(s:PERIOD_MS)
        endif

        call vimqq#log#info('Summarizing ' . file_path)
        
        " Read file content
        let file_content = join(readfile(full_path), "\n")
        
        " TODO: better error handling here
        let req = {
            \ 'content'     : file_content,
            \ 'on_complete' : {summary -> self.on_summarized(file_path, summary)},
            \ 'on_error'    : {error -> self.on_summarized(file_path, v:null)}
        \ }
        
        call self.bot.summarize(req)
    endfunction
    
    function! summ.on_summarized(file_path, summary) dict
        call self.schedule(s:PERIOD_MS)
        call self.on_summary(a:file_path, a:summary)
    endfunction

    function! summ.schedule(period_ms) dict
        call timer_start(a:period_ms, {t -> self.next()})
    endfunction

    call summ.next()

    return summ
endfunction
