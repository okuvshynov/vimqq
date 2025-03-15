" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexing_core')
    finish
endif

let g:autoloaded_vimqq_indexing_core = 1

" Finds the project root directory by looking for '.vqq' directory
" starting from the specified directory
" Returns the path to the root or v:null if not found
function! vimqq#indexing#core#find_project_root(start_dir)
    let current_dir = a:start_dir
    let prev_dir = ''

    while current_dir !=# prev_dir
        " Check if .vqq directory exists in current dir
        let vqq_dir = current_dir . '/.vqq'
        if isdirectory(vqq_dir)
            " Resolve any symlinks in the path
            return resolve(vqq_dir)
        endif

        let prev_dir = current_dir
        let current_dir = fnamemodify(current_dir, ':h')
    endwhile
    
    return v:null
endfunction

" Creates a new indexer instance for the specified starting directory
" If no directory is provided, the current working directory is used
function! vimqq#indexing#core#new(...)
    let l:indexer = {}
    let l:indexer.start_dir = a:0 > 0 ? a:1 : getcwd()

    let l:indexer.bot = vimqq#bots#llama_cpp_indexer#new({'addr' : g:vqq_indexer_addr})
    
    " Method to get the project root directory
    function! l:indexer.get_project_root() dict
        return vimqq#indexing#core#find_project_root(self.start_dir)
    endfunction
    
    " Method to get the path to the index file
    " Creates the index file if it doesn't exist
    " Returns v:null if project root cannot be found
    function! l:indexer.get_index_file() dict
        let project_root = self.get_project_root()
        
        if project_root is v:null
            call vimqq#log#warning('No .vqq directory found in project hierarchy from ' . self.start_dir)
            return v:null
        endif
        
        return vimqq#indexing#file#ensure_index_file(project_root)
    endfunction
    
    " Method to read the index file and return its contents as a dictionary
    " Returns an empty dictionary if the file cannot be read
    function! l:indexer.read_index() dict
        let index_file = self.get_index_file()
        
        if index_file is v:null
            return {}
        endif
        
        return vimqq#indexing#file#read_index(index_file)
    endfunction
    
    " Method to write a dictionary to the index file
    " Returns 1 on success, 0 on failure
    function! l:indexer.write_index(index_data) dict
        let index_file = self.get_index_file()
        
        if index_file is v:null
            call vimqq#log#error('Cannot write index: no .vqq directory found')
            return 0
        endif
        
        return vimqq#indexing#file#write_index(index_file, a:index_data)
    endfunction
    
    " Initialize files list and files_set for deduplication
    let l:indexer.files = []
    let l:indexer.files_set = {}
    
    " Method to get list of all files in the project using git ls-files
    " Uses asynchronous execution for large directories
    " Stores the result in the 'files' member variable
    " Implements queue-like behavior with deduplication
    function! l:indexer.get_git_files(...) dict
        return call('vimqq#indexing#git#get_files', [self] + a:000)
    endfunction
    
    " Method to process up to N files from the queue, counting tokens for each file's content
    " and writing the results to the JSON index
    " Returns the number of files processed, or -1 on error
    function! l:indexer.process_token_counts(max_files, ...) dict
        return call('vimqq#indexing#token#process_counts', [self, a:max_files] + a:000)
    endfunction
    
    " Method to process up to N files from the queue, generating summaries for each file's content
    " and writing the results to the JSON index
    " Returns the number of files processed, or -1 on error
    function! l:indexer.process_summaries(max_files, ...) dict
        return call('vimqq#indexing#summary#process_summaries', [self, a:max_files] + a:000)
    endfunction

    return l:indexer
endfunction
