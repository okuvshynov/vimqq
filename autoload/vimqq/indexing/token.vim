" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_token')
    finish
endif

let g:autoloaded_vimqq_indexing_token = 1

" Process up to N files from the queue, counting tokens for each file's content
" and writing the results to the JSON index
" Returns the number of files processed, or -1 on error
function! vimqq#indexing#token#process_counts(indexer, max_files, ...)
    " Check if we have a project root
    let project_root = a:indexer.get_project_root()
    if project_root is v:null
        call vimqq#log#error('Cannot process token counts: no .vqq directory found')
        return -1
    endif
    
    " Get the git repository root directory
    let git_root = fnamemodify(project_root, ':h')
    
    " Check if the queue is empty
    if empty(a:indexer.files)
        call vimqq#log#info('Token count queue is empty, nothing to process')
        return 0
    endif
    
    " Determine how many files to process (up to max_files or all available)
    let process_count = min([a:max_files, len(a:indexer.files)])
    let files_to_process = a:indexer.files[0:process_count-1]
    
    " Remove the files we're about to process from the queue
    let a:indexer.files = a:indexer.files[process_count:]
    
    " Initialize processed count
    let processed_count = 0
    
    " Set up variables for tracking completion
    let s:token_count_jobs = process_count
    let s:token_count_complete = 0
    let s:token_count_skipped = 0
    
    " Store reference to indexer for closure
    let indexer_ref = a:indexer
    let CallbackFn = a:0 > 0 && type(a:1) == v:t_func ? a:1 : v:null

    " Define callback for token count result
    function! s:on_token_count_complete(token_count, file_path) closure
        " Update the index with the token count
        let index_data = indexer_ref.read_index()

        let index_data[a:file_path] = a:token_count
        let processed_count += 1
        
        " Write the updated index
        call indexer_ref.write_index(index_data)
        
        " Log the result
        call vimqq#log#info('Indexed file: ' . a:file_path . ' (' . a:token_count . ' tokens)')
        
        " Increment completion counter
        let s:token_count_complete += 1

        " to break dependency chain
        call timer_start(0, {t -> s:enqueue_next()})
        
    endfunction

    function! s:enqueue_next() closure
        " Check if all jobs are complete
        if s:token_count_complete + s:token_count_skipped >= s:token_count_jobs
            call vimqq#log#info('All token counting complete: ' . processed_count . ' files processed')
            
            " Call the callback if provided
            if CallbackFn isnot v:null
                call CallbackFn(processed_count)
            endif
            return
        endif

        let file_path = files_to_process[s:token_count_complete + s:token_count_skipped]
        let full_path = git_root . '/' . file_path
        
        " Skip if file doesn't exist
        if !filereadable(full_path)
            call vimqq#log#warning('Skipping non-existent file: ' . file_path)
            let s:token_count_skipped += 1
            call s:enqueue_next()
        endif
        
        " Read file content
        let file_content = join(readfile(full_path), "\n")
        
        call vimqq#log#debug('Token counting for ' . file_path)
        
        " Create request object for token count
        let req = {
            \ 'content': file_content,
            \ 'on_complete': {tokens -> s:on_token_count_complete(tokens, file_path)}
        \ }
        
        " Request token count from the bot
        call indexer_ref.bot.count_tokens(req)
    endfunction

    call s:enqueue_next()
    
    " Return the number of files sent for processing
    return process_count
endfunction