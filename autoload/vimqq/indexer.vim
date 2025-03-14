" Copyright 2025 Oleksandr Kuvshynov

if exists('g:autoloaded_vimqq_indexer')
    finish
endif

let g:autoloaded_vimqq_indexer = 1

" Finds the project root directory by looking for '.vqq' directory
" starting from the specified directory
" Returns the path to the root or v:null if not found
function! s:find_project_root(start_dir)
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

" Checks for index.json in the .vqq directory
" Creates it with an empty dictionary if it doesn't exist
" Returns the path to index.json
function! s:ensure_index_file(project_root)
    let index_file = a:project_root . '/index.json'
    
    if !filereadable(index_file)
        " Create an empty dictionary as JSON
        let empty_dict = json_encode({})
        call writefile([empty_dict], index_file)
        call vimqq#log#info('Created empty index.json file at ' . index_file)
    endif
    
    " Resolve any symlinks in the path
    return resolve(index_file)
endfunction

" Creates a new indexer instance for the specified starting directory
" If no directory is provided, the current working directory is used
function! vimqq#indexer#new(...)
    let l:indexer = {}
    let l:indexer.start_dir = a:0 > 0 ? a:1 : getcwd()
    
    " Method to get the project root directory
    function! l:indexer.get_project_root() dict
        return s:find_project_root(self.start_dir)
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
        
        return s:ensure_index_file(project_root)
    endfunction
    
    " Method to read the index file and return its contents as a dictionary
    " Returns an empty dictionary if the file cannot be read
    function! l:indexer.read_index() dict
        let index_file = self.get_index_file()
        
        if index_file is v:null
            return {}
        endif
        
        if filereadable(index_file)
            let lines = readfile(index_file)
            return json_decode(join(lines, "\n"))
        endif
        
        return {}
    endfunction
    
    " Method to write a dictionary to the index file
    " Returns 1 on success, 0 on failure
    function! l:indexer.write_index(index_data) dict
        let index_file = self.get_index_file()
        
        if index_file is v:null
            call vimqq#log#error('Cannot write index: no .vqq directory found')
            return 0
        endif
        
        let json_data = json_encode(a:index_data)
        call writefile([json_data], index_file)
        return 1
    endfunction
    
    " Initialize files list and files_set for deduplication
    let l:indexer.files = []
    let l:indexer.files_set = {}
    
    " Method to get list of all files in the project using git ls-files
    " Uses asynchronous execution for large directories
    " Stores the result in the 'files' member variable
    " Implements queue-like behavior with deduplication
    function! l:indexer.get_git_files(...) dict
        " Check if we have a project root
        let project_root = self.get_project_root()
        if project_root is v:null
            call vimqq#log#error('Cannot get git files: no .vqq directory found')
            return 0
        endif
        
        " Go to parent directory of .vqq (actual project root)
        let git_root = fnamemodify(project_root, ':h')
        
        " Don't clear the files list - it's now a queue
        " Only initialize if it doesn't exist yet
        if !exists('self.files_set')
            let self.files_set = {}
        endif
        
        " Store reference to self for closure
        let indexer_ref = self
        let CallbackFn = a:0 > 0 && type(a:1) == v:t_func ? a:1 : v:null
        
        " Define output callback
        function! s:on_git_files_output(channel, output) closure
            " Split the output into lines and add to files list if not already present
            let file_list = split(a:output, "\n")
            for file in file_list
                if !empty(file) && !has_key(indexer_ref.files_set, file)
                    " Add to queue
                    call add(indexer_ref.files, file)
                    " Mark as seen in our lookup dict
                    let indexer_ref.files_set[file] = 1
                endif
            endfor
        endfunction
        
        " Define exit callback
        function! s:on_git_files_exit(job, status) closure
            if a:status == 0
                call vimqq#log#info('Git files indexed: ' . len(indexer_ref.files) . ' files found')
                
                " Call the callback if provided
                if CallbackFn isnot v:null
                    call CallbackFn(indexer_ref.files)
                endif
            else
                call vimqq#log#error('Failed to get git files. Exit status: ' . a:status)
            endif
        endfunction
        
        " Configure the job
        let job_config = {
            \ 'cwd': git_root,
            \ 'out_cb': function('s:on_git_files_output'),
            \ 'exit_cb': function('s:on_git_files_exit'),
            \ 'err_cb': {channel, msg -> vimqq#log#error('Git ls-files error: ' . msg)}
        \ }
        
        " Run the git command asynchronously
        let cmd = ['git', 'ls-files', '--cached', '--others', '--exclude-standard']
        return vimqq#platform#jobs#start(cmd, job_config)
    endfunction
    
    return l:indexer
endfunction

" For backwards compatibility: these functions use a default indexer instance
" Public function to get the project root directory
function! vimqq#indexer#get_project_root()
    let indexer = vimqq#indexer#new()
    return indexer.get_project_root()
endfunction

" Public function to get the path to the index file
function! vimqq#indexer#get_index_file()
    let indexer = vimqq#indexer#new()
    return indexer.get_index_file()
endfunction

" Reads the index file and returns its contents as a dictionary
function! vimqq#indexer#read_index()
    let indexer = vimqq#indexer#new()
    return indexer.read_index()
endfunction

" Writes a dictionary to the index file
function! vimqq#indexer#write_index(index_data)
    let indexer = vimqq#indexer#new()
    return indexer.write_index(a:index_data)
endfunction

" Gets list of all files in the project using git ls-files
" Optional callback function can be provided to process files after indexing
function! vimqq#indexer#get_git_files(...)
    let indexer = vimqq#indexer#new()
    return call(indexer.get_git_files, a:000, indexer)
endfunction
