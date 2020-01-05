let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:Process = vital#trea#import('Async.Promise.Process')

let s:SEPARATOR = has('win32') ? '\\' : '/'

function! trea#provider#file#new(path) abort
  let root = s:node(a:path)
  let root.text = fnamemodify(a:path, ':~:.:gs?\\?/?')
  return {
        \ 'get_key': funcref('s:provider_get_key'),
        \ 'get_uri': funcref('s:provider_get_uri'),
        \ 'get_root' : funcref('s:provider_get_root', [root]),
        \ 'get_children' : funcref('s:provider_get_children'),
        \}
endfunction

function! s:provider_get_key(uri) abort
  return split(fnamemodify(a:uri, ':p:gs?\\?/?'), '/')
endfunction

function! s:provider_get_uri(key) abort
  return join(a:key, s:SEPARATOR)
endfunction

function! s:provider_get_root(root) abort
  return a:root
endfunction

function! s:provider_get_children(node) abort
  if !a:node.branch
    return s:Promise.reject("non branch node does not have children")
  endif
  return s:children(a:node._path)
endfunction

function! s:norm(path) abort
  let path = fnamemodify(a:path, ':p')
  return substitute(path, s:SEPARATOR . '$', '', '')
endfunction

function! s:node(path) abort
  let path = s:norm(a:path)
  let node = {
        \ 'key': s:provider_get_key(path),
        \ 'text': fnamemodify(path, ':t'),
        \ 'branch': isdirectory(path),
        \ 'hidden': s:is_hidden(path),
        \ '_path': path,
        \}
  return node
endfunction

function! s:is_hidden(path) abort
  let basename = fnamemodify(a:path, ':t')
  return basename[:0] ==# '.'
endfunction

if executable('ls')
  function! s:children_ls(path) abort
    let path = s:norm(a:path)
    return s:Process.start(['ls', '-A', path])
          \.catch({ v -> v.stderr })
          \.then({ v -> v.stdout })
          \.then(trea#lib#lambda#filter_f({ v -> !empty(v) }))
          \.then(trea#lib#lambda#map_f({ v -> s:node(a:path . s:SEPARATOR . v) }))
  endfunction
endif

function! s:children_vim(path) abort
  let path = s:norm(a:path)
  let s = s:SEPARATOR
  let a = s:Promise.resolve(glob(path . s:SEPARATOR . '*', 1, 1, 1))
        \.then(trea#lib#lambda#map_f({ v -> s:node(v) }))
  let b = s:Promise.resolve(glob(path . s:SEPARATOR . '.*', 1, 1, 1))
        \.then(trea#lib#lambda#filter_f({ v -> v[-2:] !=# s . '.' && v[-3:] !=# s . '..' }))
        \.then(trea#lib#lambda#map_f({ v -> s:node(v) }))
  return s:Promise.all([a, b])
        \.then(trea#lib#lambda#reduce_f({ a, v -> a + v }, []))
endfunction

function! s:children(path) abort
  if !g:trea#provider#file#disable_external_process
    if exists('*s:children_ls')
      call trea#lib#message#debug("trea#provider#file: use 'ls' to get children")
      return s:children_ls(a:path)
    endif
  else
    call trea#lib#message#debug("trea#provider#file: use pure vim script to get children")
    return s:children_vim(a:path)
  endif
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_external_process': 0,
      \})
