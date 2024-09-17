if exists('g:autoloaded_vimqq_ctx_blame')
    finish
endif

let g:autoloaded_vimqq_ctx_blame = 1

let s:git_show_ctx_sz = 1
let s:git_blame_context_max_lines = 1024

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

function! vimqq#context#blame#run()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let line_range = line_start . ',' . line_end
    let file_path = expand("%:p")
    let file_dir = fnamemodify(file_path, ':h')
    let commit_hashes = s:run_git_blame(file_path, line_range)

    let res = ["Here are some relevant commits from the history:\n"]

    for commit_hash in commit_hashes
        let cmd = "cd " . file_dir . " && git show " . commit_hash . " -U" . s:git_show_ctx_sz
        let commit_lines = systemlist(cmd)
        if len(commit_lines) + len(res) > s:git_blame_context_max_lines
            break
        endif
        let res = res + commit_lines + [""]
    endfor
    return join(res, "\n")
endfunction
