if exists('g:autoloaded_vimqq_ctx_blame')
    finish
endif

let g:autoloaded_vimqq_ctx_blame = 1

function! s:run_git_blame(file_path, line_range)
    " TODO: handle errors
    let file_dir = fnamemodify(a:file_path, ':h')
    let cmd = "cd " . file_dir . " && git blame -L " . a:line_range . " " . a:file_path
    let blame_output = system(cmd)
    let commits = {}
    for line in split(blame_output, '\n')
        let parts = split(line)
        let commit_hash = parts[0]
        let commits[commit_hash] = 1
    endfor
    return keys(commits)
endfunction


" This function should run git blame on the selected lines
" and 
function! vimqq#context#blame#run()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let line_range = line_start . ',' . line_end
    let file_path = expand("%:p")
    let file_dir = fnamemodify(file_path, ':h')
    let commit_hashes = s:run_git_blame(file_path, line_range)
    let res = []

    for commit_hash in commit_hashes
        let commit_lines = systemlist("cd " . file_dir . " && git show " . commit_hash)
        let res = res + commit_lines
    endfor
    return res
endfunction
