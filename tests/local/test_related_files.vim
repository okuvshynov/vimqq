let s:suite  = themis#suite('test_related_files.vim')
let s:assert = themis#helper('assert')

" Setup test environment
function! s:suite.before() abort
    let s:temp_dir = tempname()
    let temp_dir = s:temp_dir
    call mkdir(temp_dir)
    
    " Initialize git repo
    call system('cd ' . temp_dir . ' && git init')
    call system('cd ' . temp_dir . ' && git config user.email "test@example.com"')
    call system('cd ' . temp_dir . ' && git config user.name "Test User"')
    
    " Create and commit files to establish relationships
    " Commit 1: file1.txt and file2.txt - creating a relationship
    call system('cd ' . temp_dir . ' && echo "file1 content" > file1.txt')
    call system('cd ' . temp_dir . ' && echo "file2 content" > file2.txt')
    call system('cd ' . temp_dir . ' && git add file1.txt file2.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Add file1.txt and file2.txt"')
    
    " Commit 2: file2.txt and file3.txt - creating another relationship
    call system('cd ' . temp_dir . ' && echo "file3 content" > file3.txt')
    call system('cd ' . temp_dir . ' && echo "updated content" > file2.txt')
    call system('cd ' . temp_dir . ' && git add file2.txt file3.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Add file3.txt and update file2.txt"')
    
    " Commit 3: file1.txt and file3.txt - creating a third relationship
    call system('cd ' . temp_dir . ' && echo "updated content" > file1.txt')
    call system('cd ' . temp_dir . ' && echo "updated again" > file3.txt')
    call system('cd ' . temp_dir . ' && git add file1.txt file3.txt')
    call system('cd ' . temp_dir . ' && git commit -m "Update file1.txt and file3.txt"')
    
    " Create additional commits to strengthen some relationships
    call system('cd ' . s:temp_dir . ' && echo "more updates" > file1.txt')
    call system('cd ' . s:temp_dir . ' && echo "more updates" > file2.txt')
    call system('cd ' . s:temp_dir . ' && git add file1.txt file2.txt')
    call system('cd ' . s:temp_dir . ' && git commit -m "Update file1.txt and file2.txt again"')

    " Create file with no relationships
    call system('cd ' . s:temp_dir . ' && echo "more updates" > file4.txt')
    call system('cd ' . s:temp_dir . ' && git add file4.txt')
    call system('cd ' . s:temp_dir . ' && git commit -m "Update file4.txt"')
    
    call vimqq#log#debug(system('cd ' . s:temp_dir . ' && git log'))


    return temp_dir
endfunction

function! s:suite.after() abort
    call delete(s:temp_dir, 'rf')
endfunction

function! s:suite.test_related_files_relationship_strength() abort
    " Skip if git is not available
    if !executable('git')
        call s:assert.skip('git command not available')
        return
    endif
    
    
    " Setup test repository
    let temp_dir = s:temp_dir
    let graph = {}
    let processing_complete = 0
    
    " Define completion callback
    function! s:on_complete(graph) closure
        let graph = a:graph
        let processing_complete = 1
    endfunction
    
    " Start related files processing
    call vimqq#indexing#related_files#run(temp_dir, function('s:on_complete'))
    
    " Wait for processing to complete (with timeout)
    let timeout = 5000  " 5 seconds
    let start_time = reltime()
    while !processing_complete && float2nr(reltimefloat(reltime(start_time)) * 1000) < timeout
        sleep 100m
    endwhile
    
    call s:assert.equals(graph['file1.txt']['file2.txt'], 2)
    call s:assert.equals(graph['file1.txt']['file3.txt'], 1)

    call s:assert.equals(graph['file2.txt']['file1.txt'], 2)
    call s:assert.equals(graph['file2.txt']['file3.txt'], 1)

    call s:assert.equals(graph['file3.txt']['file1.txt'], 1)
    call s:assert.equals(graph['file3.txt']['file2.txt'], 1)

    call s:assert.equals(len(graph), 3)

endfunction
