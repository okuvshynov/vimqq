" pulling some context from gh issues & prs.
" How does it work together with git blame? 
" TODO: make async. Does vim have future/promise abstraction?

if exists('g:autoloaded_vimqq_ctx_github')
    finish
endif

let g:autoloaded_vimqq_ctx_github = 1

function! s:parse_git_remote(remote_url)
    " Remove trailing newlines
    let l:remote_url = substitute(a:remote_url, '\n\+$', '', '')  

    " Handle HTTPS URL format
    let l:match = matchlist(l:remote_url, 'https://github.com/\([^/]\+/[^/]\+\)\(\.git\)$')
    if len(l:match) > 1
        return l:match[1]
    endif

    " Handle SSH URL format
    let l:match = matchlist(l:remote_url, 'git@github.com:\([^/]\+/[^/]\+\)\(\.git\)$')
    if len(l:match) > 1
        return l:match[1]
    endif

    " If no match found, return an empty string or handle the error as needed
    return ''
endfunction

function! s:guess_github_repo(file_dir)
    let cmd  = "cd " . a:file_dir . " && "
    let cmd .= "git config --get remote.origin.url"

    let output = system(cmd)
    call vimqq#log#info('github remote: ' . output)
    let output = s:parse_git_remote(output)
    call vimqq#log#info('github remote: ' . output)
    return output
endfunction

function! s:call_github_api(url)
    call vimqq#log#info(a:url)
    let token = $GITHUB_TOKEN
    let cmd  = "curl -L -s"
    let cmd .= " -H 'Accept: application/vnd.github+json'"
    let cmd .= " -H 'Authorization: Bearer " . token . "'"
    let cmd .= " -H 'X-GitHub-Api-Version: 2022-11-28'"
    let cmd .= " '" . a:url . "'"
    return json_decode(system(cmd))
endfunction

function! s:process_item(item)
    let res = ["Issue: " . a:item.title]
    let res = res + [a:item.body]
    call vimqq#log#info(a:item.body)
    call vimqq#log#info(a:item.title)
    "let comments_url = a:item.comments_url
    "let comments = s:call_github_api(comments_url)
    "let res = res + ["Comments:"]
    "for comment in comments
        "let res = res + [comment.body]
        "call vimqq#log#info(comment.body)
    "endfor
    return res
endfunction

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

function! vimqq#context#github#run()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end  , column_end  ] = getpos("'>")[1:2]
    let line_range = line_start . ',' . line_end
    let file_path = expand("%:p")
    let file_dir = fnamemodify(file_path, ':h')
    let repo = s:guess_github_repo(file_dir)
    let commit_hashes = s:run_git_blame(file_path, line_range)
    let res = ["Here are the issues and pull requests which might be relevant:"]

    for commit_hash in commit_hashes
        let res = res + s:search_query(repo, commit_hash, "is:issue")
        let res = res + s:search_query(repo, commit_hash, "is:pr")
    endfor
    return join(res, "\n")
endfunction

" type is either 'is:issue' or 'is:pr'
function! s:search_query(repo, commit_hash, type)
    let query = 'repo:' . a:repo . '+' . a:commit_hash . "+" . a:type
    let url = 'https://api.github.com/search/issues?q=' . query
    let resp = s:call_github_api(url)
    let res = []
    for item in resp.items
        let res = res + s:process_item(item)
    endfor
    return res
endfunction
