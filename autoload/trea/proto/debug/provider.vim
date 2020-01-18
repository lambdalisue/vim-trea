let s:Promise = vital#trea#import('Async.Promise')

function! trea#proto#debug#provider#new(...) abort
  let tree = a:0 ? a:1 : s:tree
  return {
        \ 'get_node' : funcref('s:provider_get_node', [tree]),
        \ 'get_parent' : funcref('s:provider_get_parent', [tree]),
        \ 'get_children' : funcref('s:provider_get_children', [tree]),
        \}
endfunction

function! s:sleep(ms) abort
  return s:Promise.new({ resolve -> timer_start(a:ms, { -> resolve() }) })
endfunction

function! s:get_entry(tree, uri) abort
  let key = matchstr(a:uri, 'debug:///\zs.*')
  if !has_key(a:tree, key)
    return v:null
  endif
  let entry = extend({'key': key}, a:tree[key])
  return entry
endfunction

function! s:provider_get_node(tree, uri) abort
  let entry = s:get_entry(a:tree, a:uri)
  return {
        \ 'name': get(split(entry.key, '/'), -1, 'root'),
        \ 'status': has_key(entry, 'children'),
        \ '_uri': a:uri,
        \}
endfunction

function! s:provider_get_parent(tree, node, ...) abort
  let uri = matchstr(a:node._uri, '.*\ze/[^/]*$')
  try
    let node = s:provider_get_node(a:tree, uri)
    return s:Promise.resolve(node)
  catch
    return s:Promise.reject(v:exception)
  endtry
endfunction

function! s:provider_get_children(tree, node, ...) abort
  let uri = a:node._uri
  let entry = s:get_entry(a:tree, a:node._uri)
  if !has_key(entry, 'children')
    return s:Promise.reject(printf('no children exists for %s', entry.key))
  endif
  let base = split(uri, '/')
  let children = s:Promise.all(map(
        \ copy(entry.children),
        \ { -> s:provider_get_node(a:tree, join(base + [v:val], '/')) },
        \))
  return s:sleep(get(entry, 'delay', 0)).then({ -> children })
endfunction


let s:tree = {
      \ '': {
      \   'parent': v:null,
      \   'children': [
      \     'shallow',
      \     'deep',
      \     'heavy',
      \     'leaf',
      \   ],
      \ },
      \ 'shallow': {
      \   'parent': '',
      \   'children': [
      \     'alpha',
      \     'beta',
      \     'gamma',
      \   ],
      \ },
      \ 'shallow/alpha': {
      \   'parent': 'shallow',
      \   'children': [],
      \ },
      \ 'shallow/beta': {
      \   'parent': 'shallow',
      \   'children': [],
      \ },
      \ 'shallow/gamma': {
      \   'parent': 'shallow',
      \ },
      \ 'deep': {
      \   'parent': '',
      \   'children': [
      \     'alpha',
      \   ],
      \ },
      \ 'deep/alpha': {
      \   'parent': 'deep',
      \   'children': [
      \     'beta',
      \   ],
      \ },
      \ 'deep/alpha/beta': {
      \   'parent': 'deep/alpha',
      \   'children': [
      \     'gamma',
      \   ],
      \ },
      \ 'deep/alpha/beta/gamma': {
      \   'parent': 'deep/alpha/beta',
      \ },
      \ 'heavy': {
      \   'delay': 1000,
      \   'parent': '',
      \   'children': [
      \     'alpha',
      \     'beta',
      \     'gamma',
      \   ],
      \ },
      \ 'heavy/alpha': {
      \   'delay': 2000,
      \   'parent': 'heavy',
      \   'children': [],
      \ },
      \ 'heavy/beta': {
      \   'delay': 3000,
      \   'parent': 'heavy',
      \   'children': [],
      \ },
      \ 'heavy/gamma': {
      \   'parent': 'heavy',
      \ },
      \ 'leaf': {
      \   'parent': '',
      \ },
      \}
