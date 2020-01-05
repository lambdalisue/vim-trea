let s:Promise = vital#trea#import('Async.Promise')

function! trea#provider#dict#new(tree) abort
  return {
        \ 'get_key': funcref('s:provider_get_key'),
        \ 'get_uri': funcref('s:provider_get_uri'),
        \ 'get_root' : funcref('s:provider_get_root', [a:tree]),
        \ 'get_children' : funcref('s:provider_get_children', [a:tree]),
        \}
endfunction

function! s:to_node(key, entry) abort
  return {
        \ "key": a:key,
        \ "text": get(a:entry, "text", a:entry.name),
        \ "branch": has_key(a:entry, "children"),
        \ "_entry": a:entry,
        \}
endfunction

function! s:provider_get_key(uri) abort
  return split(a:uri, '/')
endfunction

function! s:provider_get_uri(key) abort
  return join(a:key, '/')
endfunction

function! s:provider_get_root(tree) abort
  return s:to_node([], a:tree)
endfunction

function! s:provider_get_children(tree, node) abort
  if !a:node.branch
    return s:Promise.reject("non branch node does not have children")
  endif
  let children = map(
        \ copy(a:node._entry.children),
        \ { _, e -> s:to_node(a:node.key + [e.name], e) },
        \)
  return s:Promise.resolve(children)
endfunction

let g:trea#provider#dict#SAMPLE_TREE = {
      \ "name": "root",
      \ "children": [
      \   {
      \     "name": "alpha",
      \     "children": [
      \       {
      \         "name": "beta",
      \         "children": [
      \           {
      \             "name": "gamma",
      \             "children": [],
      \           },
      \           {
      \             "name": "delta",
      \           }
      \         ]
      \       },
      \       {
      \         "name": "epsilon",
      \       }
      \     ]
      \   },
      \   {
      \     "name": "zeta",
      \   }
      \ ]
      \}
