function! vimqq#agg#merge(d1, d2) abort
  let result = {}
  
  " First copy all keys from d1
  for [key, value] in items(a:d1)
    let result[key] = value
  endfor

  " Then merge with d2, summing up values for existing keys
  for [key, value] in items(a:d2)
    let result[key] = get(result, key, 0) + value
  endfor

  return result
endfunction