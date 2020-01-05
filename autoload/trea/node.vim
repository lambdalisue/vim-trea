let s:Promise = vital#trea#import('Async.Promise')
let s:Lambda = vital#trea#import('Lambda')

let s:STATUS_COLLAPSED = 0
let s:STATUS_EXPANDED = 1

function! trea#node#new(node, ...) abort
  let text = get(a:node, 'text', get(a:node.key, -1, 'root node'))
  let node = extend(a:node, {
        \ 'text': text,
        \ 'hidden': get(a:node, 'hidden', 0),
        \ '__parent': v:null,
        \ '__status': s:STATUS_COLLAPSED,
        \ '__processing': 0,
        \})
  let node = extend(node, a:0 ? a:1 : {})
  return node
endfunction

function! trea#node#index(key, nodes) abort
  if type(a:key) isnot# v:t_list
    throw 'trea: "key" must be a list'
  endif
  for index in range(len(a:nodes))
    if a:nodes[index].key == a:key
      return index
    endif
  endfor
  return -1
endfunction

function! trea#node#find(key, nodes) abort
  let index = trea#node#index(a:key, a:nodes)
  return index is# -1 ? v:null : a:nodes[index]
endfunction

" NOTE: Use node.__status directly when performance is the matter
function! trea#node#status(node) abort
  return a:node.__status
endfunction

" NOTE: Use node.__processing directly when performance is the matter
function! trea#node#processing(node) abort
  return a:node.__processing
endfunction

" NOTE: Use node.__parent directly when performance is the matter
function! trea#node#parent(node) abort
  return a:node.__parent
endfunction

function! trea#node#children(node, provider, ...) abort
  let options = extend({
        \ 'cache': 1,
        \}, a:0 ? a:1 : {})
  if !a:node.branch
    return s:Promise.reject('leaf node does not have children')
  elseif has_key(a:node, '__children') && options.cache
    return s:Promise.resolve(a:node.__children)
  elseif has_key(a:node, '__children_resolver')
    return a:node.__children_resolver
  endif
  let p = a:provider.get_children(a:node)
        \.then(s:Lambda.map_f({ n -> trea#node#new(n, { '__parent': a:node }) }))
        \.then({ v -> s:Lambda.pass(v, s:Lambda.let(a:node, '__children', v)) })
        \.finally({ -> s:Lambda.unlet(a:node, '__children_resolver') })
  let a:node.__children_resolver = p
  return p
endfunction

function! trea#node#reload(node, nodes, provider, comparator) abort
  if a:node.__status is# s:STATUS_COLLAPSED
    return s:Promise.resolve(copy(a:nodes))
  endif
  let k = a:node.key
  let n = len(k) - 1
  let K = n < 0 ? { v -> [] } : { v -> v.key[:n] }
  let outer = s:Promise.resolve(copy(a:nodes))
        \.then(s:Lambda.filter_f({ v -> K(v) != k  }))
  let inner = s:Promise.resolve(copy(a:nodes))
        \.then(s:Lambda.filter_f({ v -> K(v) == k  }))
        \.then(s:Lambda.filter_f({ v -> v.__status is# s:STATUS_EXPANDED }))
  let descendants = inner
        \.then({v -> copy(v)})
        \.then(s:Lambda.map_f({ v ->
        \   trea#node#children(v, a:provider, { 'cache': 0 }).then({ children ->
        \     s:Lambda.if(v.__status is# s:STATUS_EXPANDED, { -> children }, { -> []})
        \   })
        \ }))
        \.then({ v -> s:Promise.all(v) })
        \.then(s:Lambda.reduce_f({ a, v -> a + v }, []))
  return s:Promise.all([outer, inner, descendants])
        \.then(s:Lambda.reduce_f({ a, v -> a + v }, []))
        \.then({ v -> s:uniq(sort(v, a:comparator.compare)) })
endfunction

function! trea#node#expand(node, nodes, provider, comparator) abort
  if a:node.__status isnot# s:STATUS_COLLAPSED
    return s:Promise.reject(printf('node %s is not collapsed', a:node.key))
  elseif has_key(a:node, '__expand_resolver')
    return a:node.__expand_resolver
  endif
  let p = trea#node#children(a:node, a:provider)
        \.then({ v -> s:extend(a:node.key, a:nodes, v) })
        \.then({ v -> s:uniq(sort(v, a:comparator.compare)) })
        \.finally({ -> s:Lambda.unlet(a:node, '__expand_resolver') })
  call p.then({ -> s:Lambda.let(a:node, '__status', s:STATUS_EXPANDED) })
  let a:node.__expand_resolver = p
  return p
endfunction

function! trea#node#collapse(node, nodes, provider) abort
  if a:node.__status isnot# s:STATUS_EXPANDED
    return s:Promise.reject(printf('node %s is not expanded', a:node.key))
  elseif has_key(a:node, '__collapse_resolver')
    return a:node.__collapse_resolver
  endif
  let k = a:node.key
  let n = len(k) - 1
  let K = n < 0 ? { v -> [] } : { v -> v.key[:n] }
  let p = s:Promise.resolve(a:nodes)
        \.then(s:Lambda.filter_f({ v -> v.key == k || K(v) != k  }))
        \.finally({ -> s:Lambda.unlet(a:node, '__collapse_resolver') })
  call p.then({ -> s:Lambda.let(a:node, '__status', s:STATUS_COLLAPSED) })
  let a:node.__collapse_resolver = p
  return p
endfunction

function! trea#node#reveal(key, nodes, provider, comparator) abort
  let n = len(a:nodes[0].key) - 1
  let k = copy(a:key)
  let ks = []
  while len(k) - 1 > n
    call add(ks, copy(k))
    call remove(k, -1)
  endwhile
  return s:expand_recursively(ks, a:nodes, a:provider, a:comparator)
endfunction

function! s:uniq(nodes) abort
  return uniq(a:nodes, { a, b -> a.key != b.key })
endfunction

function! s:extend(key, nodes, new_nodes) abort
  let index = trea#node#index(a:key, a:nodes)
  return index is# -1 ? a:nodes : extend(a:nodes, a:new_nodes, index + 1)
endfunction

function! s:expand_recursively(keys, nodes, provider, comparator) abort
  let node = trea#node#find(a:keys[-1], a:nodes)
  if node is# v:null
    return s:Promise.reject(printf(
          \ 'no node %s exists',
          \ a:keys[-1],
          \))
  endif
  return trea#node#expand(node, a:nodes, a:provider, a:comparator)
        \.then({ v -> s:Lambda.pass(v, remove(a:keys, -1)) })
        \.then({ v -> s:Lambda.if(
        \   len(a:keys) > 1,
        \   { -> s:expand_recursively(a:keys, v, a:provider, a:comparator) },
        \   { -> v },
        \ )})
endfunction


let g:trea#node#STATUS_COLLAPSED = s:STATUS_COLLAPSED
let g:trea#node#STATUS_EXPANDED = s:STATUS_EXPANDED
