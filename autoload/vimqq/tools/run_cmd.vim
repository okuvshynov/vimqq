if exists('g:autoloaded_vimqq_tools_run_cmd_module')
    finish
endif

let g:autoloaded_vimqq_tools_run_cmd_module = 1

function! vimqq#tools#run_cmd#new(root) abort
    let tool = {}

    let tool._root = a:root

    function! tool.name() dict
        return 'run_cmd'
    endfunction

    function! tool.schema() dict
        return {
        \ "type": "function",
        \   "function": {
        \     "name": "run_cmd",
        \     "description": "Runs a shell command and returns stdout, stderr and return code",
        \     "parameters": {
        \       "type": "object",
        \       "properties": {
        \         "command": {
        \           "type": "string",
        \           "description": "Shell command to run"
        \         }
        \       },
        \       "required": ["command"],
        \     },
        \   },
        \ }
    endfunction

    function! tool.run_async(tool_use_args, callback) abort dict
        let cmd = a:tool_use_args['command']

        if exists('*mkdir')
            let tempdir = fnamemodify(tempname(), ':h') 
            let stdout_file = tempdir . '/vqq_stdout_' . getpid()
            let stderr_file = tempdir . '/vqq_stderr_' . getpid()
            let returncode_file = tempdir . '/vqq_rc_' . getpid()
        else 
            let stdout_file = '/tmp/vqq_stdout_' . getpid()
            let stderr_file = '/tmp/vqq_stderr_' . getpid()
            let returncode_file = '/tmp/vqq_rc_' . getpid()
        endif

        " Prepare shell wrapper that captures stdout, stderr and return code
        let shell_cmd = cmd . ' > ' . stdout_file . ' 2> ' . stderr_file . '; echo $? > ' . returncode_file

        let stdout = []
        let stderr = []
        let rc = -1

        let config = {}

        function! s:on_close(channel) closure
            let result = {
                \ 'stdout': join(readfile(stdout_file), "\n"),
                \ 'stderr': join(readfile(stderr_file), "\n"),
                \ 'returncode': str2nr(join(readfile(returncode_file), ''))
                \ }

            " Cleanup temp files
            call delete(stdout_file)
            call delete(stderr_file) 
            call delete(returncode_file)

            call a:callback(json_encode(result))
        endfunction

        let config['close_cb'] = function('s:on_close')
        call vimqq#platform#jobs#start([&shell, &shellcmdflag, shell_cmd], config)
    endfunction

    return tool
endfunction
