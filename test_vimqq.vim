set nocompatible
syntax on

let g:qq_server = "http://studio.local:8080"

source prefetch.vim
let &runtimepath.=','.escape(expand('<sfile>:p:h'), '\,')
