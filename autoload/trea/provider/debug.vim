let s:Promise = vital#trea#import('Async.Promise')

function! trea#provider#debug#new(...) abort
  return {
        \ 'get_key': funcref('s:provider_get_key'),
        \ 'get_uri': funcref('s:provider_get_uri'),
        \ 'get_root' : funcref('s:provider_get_root'),
        \ 'get_children' : funcref('s:provider_get_children'),
        \}
endfunction

function! s:provider_get_key(uri) abort
  return split(a:uri, '/')
endfunction

function! s:provider_get_uri(key) abort
  return join(a:key, '/')
endfunction

function! s:provider_get_root() abort
  return {
        \ 'key': [],
        \ 'text': 'root',
        \ 'branch': 1,
        \}
endfunction

function! s:provider_get_children(node) abort
  if a:node.key == []
    return s:Promise.resolve([
          \ {
          \   'key': ['narrow'],
          \   'text': 'narrow',
          \   'branch': 1,
          \ },
          \ {
          \   'key': ['deep'],
          \   'text': 'deep',
          \   'branch': 1,
          \ },
          \ {
          \   'key': ['heavy'],
          \   'text': 'heavy',
          \   'branch': 1,
          \ },
          \ {
          \   'key': ['leaf'],
          \   'text': 'leaf',
          \   'branch': 0,
          \ },
          \])
  elseif a:node.key == ['narrow']
    return s:Promise.resolve([
          \ {
          \   'key': ['narrow', 'a'],
          \   'text': 'a',
          \   'branch': 0,
          \ },
          \ {
          \   'key': ['narrow', 'b'],
          \   'text': 'b',
          \   'branch': 0,
          \ },
          \ {
          \   'key': ['narrow', 'c'],
          \   'text': 'c',
          \   'branch': 0,
          \ },
          \])
  elseif a:node.key == ['deep']
    return s:Promise.resolve([
          \ {
          \   'key': ['deep', 'a'],
          \   'text': 'a',
          \   'branch': 1,
          \ },
          \])
  elseif a:node.key == ['deep', 'a']
    return s:Promise.resolve([
          \ {
          \   'key': ['deep', 'a', 'b'],
          \   'text': 'b',
          \   'branch': 1,
          \ },
          \])
  elseif a:node.key == ['deep', 'a', 'b']
    return s:Promise.resolve([
          \ {
          \   'key': ['deep', 'a', 'b', 'c'],
          \   'text': 'c',
          \   'branch': 0,
          \ },
          \])
  elseif a:node.key == ['heavy']
    function! s:heavy_children(resolve, reject) abort
      call timer_start(3000, { -> a:resolve([
            \ {
            \   'key': ['heavy', 'a'],
            \   'text': 'a',
            \   'branch': 0,
            \ },
            \ {
            \   'key': ['heavy', 'b'],
            \   'text': 'b',
            \   'branch': 0,
            \ },
            \ {
            \   'key': ['heavy', 'c'],
            \   'text': 'c',
            \   'branch': 0,
            \ },
            \])})
    endfunction
    return s:Promise.new(funcref('s:heavy_children'))
  else
    return s:Promise.reject(printf(
          \ 'unknown node %s has specified',
          \ a:node.key,
          \))
  endif
endfunction
