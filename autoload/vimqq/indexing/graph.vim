if exists('g:autoloaded_vimqq_indexing_graph')
    finish
endif

let g:autoloaded_vimqq_indexing_graph = 1

let s:GRAPH_INDEX_NAME = 'commit_graph.idx'

function! vimqq#indexing#graph#run()
    let idx = {}

    let idx.root = vimqq#indexing#io#root()
    if idx.root is v:null
        call vimqq#log#warning('No indexing configured. Retry in ' . s:RETRY_IN_MS . 'ms')
        call timer_start(s:RETRY_IN_MS, {t -> vimqq#indexing#graph#run()})
        return
    endif

    function! idx.on_graph(graph) dict
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
