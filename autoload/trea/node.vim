let s:Promise = vital#trea#import('Async.Promise')
let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:CancellationToken = vital#trea#import('Async.CancellationToken')

let s:STATUS_NONE = 0
let s:STATUS_COLLAPSED = 1
let s:STATUS_EXPANDED = 2

function! trea#node#new(node, ...) abort
  let label = get(a:node, 'label', a:node.name)
  let node = extend(a:node, {
        \ 'label': label,
        \ 'hidden': get(a:node, 'hidden', 0),
        \ '__key': [],
        \ '__parent': v:null,
        \})
  let node = extend(node, a:0 ? a:1 : {})
  return node
endfunction

function! trea#node#index(key, nodes) abort
  if type(a:key) isnot# v:t_list
    throw 'trea: "key" must be a list'
  endif
  for index in range(len(a:nodes))
    if a:nodes[index].__key == a:key
      return index
    endif
  endfor
  return -1
endfunction

function! trea#node#find(key, nodes) abort
  let index = trea#node#index(a:key, a:nodes)
  return index is# -1 ? v:null : a:nodes[index]
endfunction

" NOTE: Use node.__key directly when performance is the matter
function! trea#node#key(node) abort
  return a:node.__key
endfunction

" NOTE: Use node.__parent directly when performance is the matter
function! trea#node#parent(node) abort
  return a:node.__parent
endfunction

function! trea#node#children(node, provider, token, ...) abort
  let options = extend({
        \ 'cache': 1,
        \}, a:0 ? a:1 : {})
  if a:node.status is# s:STATUS_NONE
    return s:Promise.reject('leaf node does not have children')
  elseif has_key(a:node, '__children') && options.cache
    return s:AsyncLambda.map(
          \ a:node.__children,
          \ { v -> extend(v, { 'status': v.status > 0 }) },
          \)
  elseif has_key(a:node, '__children_resolver')
    return a:node.__children_resolver
  endif
  let p = a:provider.get_children(a:node, a:token)
        \.then(s:AsyncLambda.map_f({ n ->
        \   trea#node#new(n, {
        \     '__key': a:node.__key + [n.name],
        \     '__parent': a:node,
        \   })
        \ }))
        \.then({ v -> s:Lambda.pass(v, s:Lambda.let(a:node, '__children', v)) })
        \.finally({ -> s:Lambda.unlet(a:node, '__children_resolver') })
  let a:node.__children_resolver = p
  return p
endfunction

function! trea#node#reload(node, nodes, provider, comparator, token) abort
  if a:node.status is# s:STATUS_NONE || a:node.status is# s:STATUS_COLLAPSED
    return s:Promise.resolve(copy(a:nodes))
  elseif has_key(a:node, '__expand_resolver')
    return a:node.__expand_resolver
  elseif has_key(a:node, '__collapse_resolver')
    return a:node.__collapse_resolver
  endif
  let k = a:node.__key
  let n = len(k) - 1
  let K = n < 0 ? { v -> [] } : { v -> v.__key[:n] }
  let outer = s:Promise.resolve(copy(a:nodes))
        \.then(s:AsyncLambda.filter_f({ v -> K(v) != k  }))
  let inner = s:Promise.resolve(copy(a:nodes))
        \.then(s:AsyncLambda.filter_f({ v -> K(v) == k  }))
        \.then(s:AsyncLambda.filter_f({ v -> v.status is# s:STATUS_EXPANDED }))
  let descendants = inner
        \.then({v -> copy(v)})
        \.then(s:AsyncLambda.map_f({ v ->
        \   trea#node#children(v, a:provider, a:token, { 'cache': 0 }).then({ children ->
        \     s:Lambda.if(v.status is# s:STATUS_EXPANDED, { -> children }, { -> []})
        \   })
        \ }))
        \.then({ v -> s:Promise.all(v) })
        \.then(s:AsyncLambda.reduce_f({ a, v -> a + v }, []))
  return s:Promise.all([outer, inner, descendants])
        \.then(s:AsyncLambda.reduce_f({ a, v -> a + v }, []))
        \.then({ v -> s:uniq(sort(v, a:comparator.compare)) })
endfunction

function! trea#node#expand(node, nodes, provider, comparator, token) abort
  if a:node.status is# s:STATUS_NONE || a:node.status is# s:STATUS_EXPANDED
    return s:Promise.resolve(copy(a:nodes))
  elseif has_key(a:node, '__expand_resolver')
    return a:node.__expand_resolver
  elseif has_key(a:node, '__collapse_resolver')
    return a:node.__collapse_resolver
  endif
  let p = trea#node#children(a:node, a:provider, a:token)
        \.then({ v -> s:extend(a:node.__key, a:nodes, v) })
        \.then({ v -> s:uniq(sort(v, a:comparator.compare)) })
        \.finally({ -> s:Lambda.unlet(a:node, '__expand_resolver') })
  call p.then({ -> s:Lambda.let(a:node, 'status', s:STATUS_EXPANDED) })
  let a:node.__expand_resolver = p
  return p
endfunction

function! trea#node#collapse(node, nodes, provider) abort
  if a:node.status is# s:STATUS_NONE || a:node.status is# s:STATUS_COLLAPSED
    return s:Promise.resolve(copy(a:nodes))
  elseif has_key(a:node, '__expand_resolver')
    return a:node.__expand_resolver
  elseif has_key(a:node, '__collapse_resolver')
    return a:node.__collapse_resolver
  endif
  let k = a:node.__key
  let n = len(k) - 1
  let K = n < 0 ? { v -> [] } : { v -> v.__key[:n] }
  let p = s:Promise.resolve(a:nodes)
        \.then(s:AsyncLambda.filter_f({ v -> v.__key == k || K(v) != k  }))
        \.finally({ -> s:Lambda.unlet(a:node, '__collapse_resolver') })
  call p.then({ -> s:Lambda.let(a:node, 'status', s:STATUS_COLLAPSED) })
  let a:node.__collapse_resolver = p
  return p
endfunction

function! trea#node#reveal(key, nodes, provider, comparator, token) abort
  if a:key == a:nodes[0].__key
    return s:Promise.resolve(a:nodes)
  endif
  let n = len(a:nodes[0].__key) - 1
  let k = copy(a:key)
  let ks = []
  while len(k) - 1 > n
    call add(ks, copy(k))
    call remove(k, -1)
  endwhile
  return s:expand_recursively(ks, a:nodes, a:provider, a:comparator, token)
endfunction

function! s:uniq(nodes) abort
  return uniq(a:nodes, { a, b -> a.__key != b.__key })
endfunction

function! s:extend(key, nodes, new_nodes) abort
  let index = trea#node#index(a:key, a:nodes)
  return index is# -1 ? a:nodes : extend(a:nodes, a:new_nodes, index + 1)
endfunction

function! s:expand_recursively(keys, nodes, provider, comparator, token) abort
  let node = trea#node#find(a:keys[-1], a:nodes)
  if node is# v:null
    return s:Promise.reject(printf(
          \ 'no node %s exists',
          \ a:keys[-1],
          \))
  endif
  return trea#node#expand(node, a:nodes, a:provider, a:comparator, token)
        \.then({ v -> s:Lambda.pass(v, remove(a:keys, -1)) })
        \.then({ v -> s:Lambda.if(
        \   len(a:keys) > 1,
        \   { -> s:expand_recursively(a:keys, v, a:provider, a:comparator, token) },
        \   { -> v },
        \ )})
endfunction


let g:trea#node#STATUS_NONE = s:STATUS_NONE
let g:trea#node#STATUS_COLLAPSED = s:STATUS_COLLAPSED
let g:trea#node#STATUS_EXPANDED = s:STATUS_EXPANDED
