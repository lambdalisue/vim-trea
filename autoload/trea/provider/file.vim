let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:Process = vital#trea#import('Async.Promise.Process')

function! trea#provider#file#new() abort
  return {
        \ 'get_node': funcref('s:provider_get_node'),
        \ 'get_parent' : funcref('s:provider_get_parent'),
        \ 'get_children' : funcref('s:provider_get_children'),
        \}
endfunction

function! s:provider_get_node(uri) abort
 return s:node(matchstr(a:uri, 'file://\zs.*'))
endfunction

function! s:provider_get_parent(node) abort
  if a:node._path ==# '/'
    return v:null
  endif
  let parent = fnamemodify(a:node._path, ':h')
  return s:Promise.resolve(s:node(parent))
endfunction

function! s:provider_get_children(node) abort
  if a:node.status is# 0
    return s:Promise.reject("no children exists for %s", a:node._path)
  endif
  return s:children(a:node._path)
        \.then(s:AsyncLambda.map_f({ v -> s:node(v) }))
endfunction

function! s:norm(path) abort
  if a:path ==# '/'
    return '/'
  endif
  let abspath = fnamemodify(a:path, ':p')
  let abspath = matchstr(abspath, '.\{-}\ze/\?$')
  return abspath
endfunction

function! s:node(path) abort
  let path = s:norm(a:path)
  let name = fnamemodify(path, ':t')
  let status = isdirectory(path)
  return {
        \ 'name': name,
        \ 'label': name ==# '' ? '/' : name,
        \ 'status': status,
        \ 'hidden': name[:0] ==# '.',
        \ '_path': path,
        \}
endfunction

if executable('find')
  function! s:children_find(path) abort
    let path = s:norm(a:path)
    return s:Process.start(['find', path, '-maxdepth', '1'])
         \.then({ v -> v.stdout })
         \.then(s:AsyncLambda.filter_f({ v -> !empty(v) && v !=# path }))
  endfunction
endif

if executable('ls')
  function! s:children_ls(path) abort
    let path = s:norm(a:path)
    return s:Process.start(['ls', '-1A', path])
         \.then({ v -> v.stdout })
         \.then(s:AsyncLambda.filter_f({ v -> !empty(v) }))
         \.then(s:AsyncLambda.map_f({ v -> path . '/' . v }))
  endfunction
endif

function! s:children_vim(path) abort
  let path = s:norm(a:path)
  let a = s:Promise.resolve(glob(path . '/*', 1, 1, 1))
  let b = s:Promise.resolve(glob(path . '/.*', 1, 1, 1))
        \.then(s:AsyncLambda.filter_f({ v -> v !=# path . '/.' && v !=# path .'/..' }))
  return s:Promise.all([a, b])
        \.then(s:AsyncLambda.reduce_f({ a, v -> a + v }, []))
endfunction

function! s:children(path) abort
  return call(printf('s:children_%s', g:trea#provider#file#impl), [a:path])
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'impl': executable('find') ? 'find' : executable('ls') ? 'ls' : 'vim',
      \})
