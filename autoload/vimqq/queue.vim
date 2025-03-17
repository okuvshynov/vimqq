" Copyright 2025 Oleksandr Kuvshynov
" -----------------------------------------------------------------------------
if exists('g:autoloaded_vimqq_queue')
    finish
endif

let g:autoloaded_vimqq_queue = 1

" Creates a new queue instance
function! vimqq#queue#new()
    let queue = {}
    
    " Initialize the queue as an empty list
    let queue._items = []
    let queue._items_set = {}
    
    " Check if an item is already in the queue using string equality
    function! queue._contains(item) dict
        return has_key(self._items_set, a:item)
    endfunction
    
    " Add an item to the queue if it's not already present
    function! queue.enqueue(item) dict
        if !self._contains(a:item)
            call add(self._items, a:item)
            let self._items_set[a:item] = 1
            return 1
        endif
        return 0
    endfunction
    
    " Remove and return the first item from the queue
    function! queue.dequeue() dict
        if empty(self._items)
            return v:null
        endif
        
        let item = self._items[0]
        let self._items = self._items[1:]
        unlet self._items_set[item]
        return item
    endfunction
    
    " Get the size of the queue
    function! queue.size() dict
        return len(self._items)
    endfunction
    
    " Check if the queue is empty
    function! queue.is_empty() dict
        return empty(self._items)
    endfunction
    
    " Peek at the first item without removing it
    function! queue.peek() dict
        if empty(self._items)
            return v:null
        endif
        
        return self._items[0]
    endfunction
    
    " Get all items in the queue
    function! queue.get_all() dict
        return copy(self._items)
    endfunction
    
    " Clear all items from the queue
    function! queue.clear() dict
        let self._items = []
    endfunction
    
    return queue
endfunction
