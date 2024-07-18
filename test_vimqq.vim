syntax on
set nocompatible

source prefetch.vim
let &runtimepath.=','.escape(expand('<sfile>:p:h'), '\,')
