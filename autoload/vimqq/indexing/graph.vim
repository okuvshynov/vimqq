if exists('g:autoloaded_vimqq_indexing_graph')
    finish
endif

let g:autoloaded_vimqq_indexing_graph = 1

let s:GRAPH_INDEX_NAME = 'commit_graph.idx'
let s:INDEX_NAME       = 'graph_index'
" TODO: make this token-based, not hardcoded
let s:CONTEXT_SIZE     = 10

function! vimqq#indexing#graph#build_graph()
    let idx = {}

    let idx.root = vimqq#indexing#io#root()
    if idx.root is v:null
        call vimqq#log#warning('No indexing configured. .vqq directory not found.')
        return
    endif

    function! idx.on_graph(graph) dict
        call vimqq#main#status_update('commit_graph_completed', strftime("%X"))
        call vimqq#indexing#io#write(s:GRAPH_INDEX_NAME, a:graph)
    endfunction

    let idx.graph_builder = vimqq#indexing#related_files#run(idx.root, {g -> idx.on_graph(g)})

    return idx
endfunction

function! vimqq#indexing#graph#get_top_n(file_path, n)
    let graph = vimqq#indexing#io#read(s:GRAPH_INDEX_NAME)
    let edges = get(graph, a:file_path, {})
    let items = []
    for [label, cnt] in items(edges)
        call add(items, [label, cnt])
    endfor
    
    " Sort by count in descending order
    call sort(items, {a, b -> b[1] - a[1]})
    
    " Extract the top n labels
    let result = []
    let i = 0
    while i < a:n && i < len(items)
        call add(result, items[i][0])
        let i += 1
    endwhile
    
    return result
endfunction

" Assumes graph is there
function! vimqq#indexing#graph#build_index()
    let idx = {}
    let idx.counters = {}
    let idx.root = vimqq#indexing#io#root()
    if idx.root is v:null
        call vimqq#log#warning('No indexing configured. .vqq directory not found.')
        return
    endif

    let idx.bot = vimqq#bots#llama_cpp_indexer#new({'addr' : g:vqq_indexer_addr})

    let idx.ignores = vimqq#indexing#io#ignores()
    call vimqq#log#info('Ingoring patterns: ' . string(idx.ignores))

    let idx.crawler = vimqq#indexing#git#get_files(
        \ idx.root,
        \ {f -> idx.on_file(f)},
        \ {fc -> idx.on_crawl_complete()}
    \ )

    let idx.new_data = {}

    function! idx.inc(key) dict
        let self.counters[a:key] = get(self.counters, a:key, 0) + 1
        call vimqq#main#status_update('index: ' . a:key, self.counters[a:key])
    endfunction

    " When we got new file
    function! idx.on_file(file_path) dict
        if vimqq#util#path_matches_patterns(a:file_path, self.ignores)
            call self.inc('n_files_ignored')
            return
        endif
        let full_path = self.root . '/' . a:file_path
        if !filereadable(full_path)
            call self.inc('n_files_not_found')
            return
        endif
        let checksum = vimqq#platform#checksum#sha256(full_path)
        let content = join(readfile(full_path), "\n")
        let file_data = vimqq#indexing#io#read_path(s:INDEX_NAME, a:file_path)
        if get(file_data, 'checksum', '') ==# checksum
            " reuse the old summary
            call self.inc('n_files_reused')
            return
        endif
        let self.new_data[a:file_path] = {'checksum' : checksum}
        let context = vimqq#indexing#graph#get_top_n(a:file_path, s:CONTEXT_SIZE)
        let prompt = vimqq#prompts#indexing_file_ctx()
        let entries = ['\n' . a:file_path . '\n' . content]
        for ctx_file in content
            let ctx_file_path = self.root . '/' . ctx_file
            if filereadable(ctx_file_path)
                call add(entries, ctx_file . '\n' . join(readfile(ctx_file_path), '\n'))
            endif
        endfor
        let prompt = prompt . join(entries, '\n')
        let request = {
            \ 'content'     : prompt,
            \ 'on_complete' : {s -> self.on_complete(a:file_path, s)},
            \ 'on_error'    : {e -> self.on_error(a:file_path, e)}
        \ }
        call self.bot.message(request)
        call self.inc('n_files_enqueued')
    endfunction

    function! idx.on_crawl_complete() dict
        call vimqq#log#info('Crawl completed')
    endfunction

    function! idx.on_complete(file_path, summary) dict
        call vimqq#log#debug('Recording summary for ' . a:file_path)
        call self.inc('n_files_summarized')
        let data = self.new_data[a:file_path]
        let data['summary'] = a:summary
        call vimqq#indexing#io#write_path(s:INDEX_NAME, a:file_path, data)
    endfunction

    function! idx.on_error(file_path, error) dict
        call vimqq#log#error('indexing error: ' . string(a:file_path) . ' : ' . string(a:error))
        call self.inc('n_errors')
        if has_key(self.new_data, a:file_path)
        endif
    endfunction

endfunction

function! vimqq#indexing#graph#format()
    let summaries = vimqq#indexing#io#collect(s:INDEX_NAME)
    let res = []
    for [file_path, summary] in items(summaries)
        call add(res, file_path)
        call add(res, summary)
        call add(res, '')
    endfor
    return join(res, "\n")
endfunction
