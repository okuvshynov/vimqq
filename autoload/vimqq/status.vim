if exists('g:autoloaded_vimqq_status')
    finish
endif

let g:autoloaded_vimqq_status = 1

function! vimqq#status#new()
    " This class collects current status of the vimqq system
    " Including all in-progress chats, indexing, etc
    let status = {}

    let status.values = {}

    function! status.update(key, message=v:null) dict
        if a:message is v:null
            unlet! self.values[a:key]
        else
            let self.values[a:key] = a:message
        endif
    endfunction

    function! status.render() dict
        let lines = []
        
        " Check if values dictionary is empty
        if empty(self.values)
            return []
        endif
        
        " Find the longest key length
        let max_key_length = 0
        for key in keys(self.values)
            let key_length = len(key)
            if key_length > max_key_length
                let max_key_length = key_length
            endif
        endfor
        
        " Add padding (2 spaces after longest key)
        let padding = max_key_length + 2
        
        " Format each key-value pair
        for [key, value] in items(self.values)
            let padded_key = key . repeat(' ', padding - len(key))
            call add(lines, padded_key . value)
        endfor
        
        return lines
        
    endfunction

    return status
endfunction
