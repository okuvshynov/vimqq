function! ASSERT_EQ_CHATS(observed, expected)
    if len(a:expected) != len(a:observed)
        call vimqq#log#info('Chat length does not match:')
        call vimqq#log#info(len(a:expected))
        call vimqq#log#info(len(a:observed))
        cquit 1
    endif
    for i in range(len(a:expected))
        let curr = substitute(a:observed[i], '^\d\{2}:\d\{2}', '00:00', '')
        if a:expected[i] != curr
            call vimqq#log#info(a:expected[i])
            call vimqq#log#info(curr)
            cquit 1
        endif
    endfor
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

function! ASSERT_EQ_DICT(dict1, dict2)
    let result = DeepDictCompareImpl(a:dict1, a:dict2)
    if result != 0
        echoe 'ERROR: dictionaries are not equal'
        echoe a:dict1
        echoe a:dict2
        cquit 1
    endif
endfunction

function! ASSERT_TRUE(a)
    if !a:a
        cquit 1
    endif
endfunction

function! ASSERT_EQ(a, b)
    if a:a != a:b
        echom "ASSERT_EQ failed:"
        echom a:a
        echom a:b
        cquit 1
    endif
endfunction

function! ASSERT_GT(a, b)
    if a:a <= a:b
        cquit 1
    endif
endfunction

function! ASSERT_EQ_ARRAY(a, b)
    if len(a:a) != len(a:b)
        cquit 1
    endif
    for i in range(len(a:a))
        if a:a[i] != a:b[i]
            cquit 1
        endif
    endfor
endfunction

function! DELAYED_VERIFY(timeout, fn)
    call timer_start(a:timeout, {t -> [
        \ a:fn(),
        \ execute('cquit 0')
    \ ]})
endfunction

function! RunAllTests()
    let functions = execute('function')
    
    " Split into lines and filter for Test_ functions
    let func_list = split(functions, "\n")
    let test_funcs = filter(func_list, 'v:val =~ "^function Test_"')
    
    " Extract just the function names and call each one
    for func in test_funcs
        " Extract function name (between 'function' and '(')
        let func_name = matchstr(func, 'function \zs\k*\ze(')
        execute 'call ' . func_name . '()'
    endfor
    cquit 0
endfunction

