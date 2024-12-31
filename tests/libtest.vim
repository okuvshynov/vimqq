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

function! DeepDictCompareImpl(dict1, dict2)
    " Check if both inputs are dictionaries
    if type(a:dict1) != type({}) || type(a:dict2) != type({})
        return 1
    endif

    " Check if dictionaries have same number of keys
    if len(a:dict1) != len(a:dict2)
        return 1
    endif

    " Compare each key-value pair recursively
    for [key, value] in items(a:dict1)
        " Check if key exists in second dictionary
        if !has_key(a:dict2, key)
            return 1
        endif

        " Get value from second dictionary
        let value2 = a:dict2[key]

        " If both values are dictionaries, recurse
        if type(value) == type({}) && type(value2) == type({})
            if !DeepDictCompare(value, value2)
                return 1
            endif
        " If both values are lists, compare them
        elseif type(value) == type([]) && type(value2) == type([])
            if value != value2
                return 1
            endif
        " For all other types, do direct comparison
        else
            if value != value2
                return 1
            endif
        endif
    endfor

    return 0
endfunction

function! DeepDictCompare(dict1, dict2)
    let result = DeepDictCompareImpl(a:dict1, a:dict2)
    if result != 0
        echoe 'ERROR: dictionaries are not equal'
        echoe a:dict1
        echoe a:dict2
    endif
    return result
endfunction

function! ArrayCompare(a, b)
    if len(a:a) != len(a:b)
        return 1
    endif
    for i in range(len(a:a))
        if a:a[i] != a:b[i]
            return 1
        endif
    endfor
    return 0
endfunction
