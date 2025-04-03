if exists('g:autoloaded_vimqq_usage_module')
    finish
endif

let g:autoloaded_vimqq_usage_module = 1

" data model for usage:
" (chat_id, bot) -> usage dict
function! vimqq#usage#new()
    let u = {}

    " we double-write here for easy querying
    let u.by_chat = {}

    function! u.merge(chat_id, bot_name, usage) dict
        let per_bot = get(self.by_chat, a:chat_id, {})
        let current = get(per_bot, a:bot_name, {})
        let per_bot[a:bot_name] = vimqq#util#merge(current, a:usage)
        let self.by_chat[a:chat_id] = per_bot
    endfunction

    function! u.get(chat_id) dict
        return get(self.by_chat, a:chat_id, {})
    endfunction

    return u
endfunction
