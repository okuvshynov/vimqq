" Copyright 2024 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_local_indexer_module')
    finish
endif

let g:autoloaded_vimqq_local_indexer_module = 1
let g:vqq_local_indexer_addr = get(g:, 'vqq_local_indexer_addr', '')


function! vimqq#bots#local_indexer#new() abort
    let indexer = {}
    let server = substitute(g:vqq_local_indexer_addr, '/*$', '', '')
    let endpoint = server . '/v1/chat/completions'

    let indexer.api = vimqq#api#llama_api#new(endpoint)
    let indexer.jobs = []

    function! indexer.run(file_path, OnDone) abort dict
        let root = vimqq#util#project_root()
        let l_file_path = a:file_path
        let file_path = root . '/' . a:file_path
        let content = ""
        call vimqq#log#debug('local_indexer: indexing ' . a:file_path)
        if filereadable(file_path)
            let content = join(readfile(file_path), "\n")
        else
            call vimqq#log#error('Indexed file ' . file_path . ' not readable')
        endif

        let messages = [
            \ {'role': 'system', 'content': vimqq#prompts#crawler_prompt()},
            \ {'role': 'user', 'content': "<file>\n" . content . "\n</file>"}
        \ ]

        let OnDone = a:OnDone
        let current_content = ''

        let _self = self

        function! OnChunk(chunk) closure
            let current_content .= a:chunk
        endfunction

        " decouple so we can redefine
        function! OnComplete() closure
            call timer_start(0, { -> OnDone(l_file_path, current_content)})
            call timer_start(0, { -> _self.mark_done()})
        endfunction

        let req = {
            \ 'messages' : messages,
            \ 'max_tokens' : 1024,
            \ 'stream' : v:false,
            \ 'on_chunk' : {p, m -> OnChunk(m) },
            \ 'on_complete' : {err, p -> OnComplete()}
        \ }

        return self.api.chat(req)
    endfunction

    function! indexer.enqueue(file_path, OnDone) abort dict
        call add(self.jobs, [a:file_path, a:OnDone])
        if len(self.jobs) == 1
            call self.run(self.jobs[0][0], self.jobs[0][1])
        endif
    endfunction

    function! indexer.mark_done() abort dict
        call remove(self.jobs, 0)
        if len(self.jobs) > 0
            call self.run(self.jobs[0][0], self.jobs[0][1])
        endif
    endfunction

    return indexer

endfunction

