function! VQQCompareChats(content, expected)
    call vimqq#log#info(len(a:content))
    call vimqq#log#info(len(a:expected))
    if len(a:expected) != len(a:content)
        return 1
    endif
    for i in range(len(a:expected))
        let curr = substitute(a:content[i], '^\d\{2}:\d\{2}', '00:00', '')
        call vimqq#log#info(curr)
        call vimqq#log#info(a:expected[i])
        if a:expected[i] != curr
            return 1
        endif
    endfor

    return 0
endfunction

