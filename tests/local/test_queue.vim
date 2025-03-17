let s:suite = themis#suite('Queue Tests')
let s:assert = themis#helper('assert')

function! s:suite.test_create_queue()
    let queue = vimqq#queue#new()
    call s:assert.equals(queue.size(), 0)
    call s:assert.true(queue.is_empty())
endfunction

function! s:suite.test_enqueue_dequeue()
    let queue = vimqq#queue#new()
    
    " Test enqueue
    call s:assert.true(queue.enqueue('item1'))
    call s:assert.equals(queue.size(), 1)
    call s:assert.false(queue.is_empty())
    
    " Test peek
    call s:assert.equals(queue.peek(), 'item1')
    call s:assert.equals(queue.size(), 1)
    
    " Test enqueue more items
    call s:assert.true(queue.enqueue('item2'))
    call s:assert.equals(queue.size(), 2)
    
    " Test dequeue
    call s:assert.equals(queue.dequeue(), 'item1')
    call s:assert.equals(queue.size(), 1)
    call s:assert.equals(queue.dequeue(), 'item2')
    call s:assert.equals(queue.size(), 0)
    call s:assert.true(queue.is_empty())
    
    " Test dequeue on empty queue
    call s:assert.equals(queue.dequeue(), v:null)
endfunction

function! s:suite.test_duplicate_prevention()
    let queue = vimqq#queue#new()
    
    " Test adding duplicate strings
    call s:assert.true(queue.enqueue('item1'))
    call s:assert.false(queue.enqueue('item1'))
    call s:assert.equals(queue.size(), 1)
    
    " Test adding duplicate numbers
    call s:assert.true(queue.enqueue(42))
    call s:assert.false(queue.enqueue(42))
    call s:assert.equals(queue.size(), 2)
    
    " Test adding duplicate lists
    call s:assert.true(queue.enqueue(['a', 'b']))
    call s:assert.false(queue.enqueue(['a', 'b']))
    call s:assert.equals(queue.size(), 3)
    
    " Test adding duplicate dictionaries
    call s:assert.true(queue.enqueue({'key': 'value'}))
    call s:assert.false(queue.enqueue({'key': 'value'}))
    call s:assert.equals(queue.size(), 4)
endfunction

function! s:suite.test_get_all_and_clear()
    let queue = vimqq#queue#new()
    
    " Add items to the queue
    call queue.enqueue('item1')
    call queue.enqueue('item2')
    call queue.enqueue('item3')
    
    " Test get_all
    let all_items = queue.get_all()
    call s:assert.equals(len(all_items), 3)
    call s:assert.equals(all_items[0], 'item1')
    call s:assert.equals(all_items[1], 'item2')
    call s:assert.equals(all_items[2], 'item3')
    
    " Test clear
    call queue.clear()
    call s:assert.equals(queue.size(), 0)
    call s:assert.true(queue.is_empty())
endfunction