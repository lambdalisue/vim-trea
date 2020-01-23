let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:CancellationTokenSource = vital#trea#import('Async.CancellationTokenSource')

let s:STATUS_EXPANDED = g:trea#internal#node#STATUS_EXPANDED

function! trea#internal#core#new(url, provider, ...) abort
  let options = extend({
        \ 'reveal': [],
        \ 'comparator': trea#comparator#default#new(),
        \}, a:0 ? a:1 : {},
        \)
  let trea = {
        \ 'source': s:CancellationTokenSource.new(),
        \ 'provider': a:provider,
        \ 'comparator': options.comparator,
        \ 'marks': [],
        \ 'hidden': 0,
        \ 'pattern': '',
        \}
  return a:provider.get_node(a:url)
        \.then({ n -> trea#internal#node#new(n) })
        \.then({ n -> s:Lambda.let(trea, 'root', n) })
        \.then({ -> s:Lambda.let(trea, 'nodes', [trea.root]) })
        \.then({ -> trea })
endfunction

function! trea#internal#core#cancel(trea) abort
  call a:trea.source.cancel()
  let a:trea.source = s:CancellationTokenSource.new()
endfunction

function! trea#internal#core#update_nodes(trea, nodes) abort
  let a:trea.nodes = copy(a:nodes)
  let Hidden = a:trea.hidden
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || !v.hidden }
  let Filter = empty(a:trea.pattern)
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || v.name =~ a:trea.pattern }
  return s:Promise.resolve(a:trea.nodes)
        \.then({ ns -> s:AsyncLambda.filter(ns, Hidden) })
        \.then({ ns -> s:AsyncLambda.filter(ns, Filter) })
        \.then({ ns -> s:Lambda.pass(ns, s:Lambda.let(a:trea, 'nodes', ns)) })
        \.then({ -> trea#internal#core#update_marks(a:trea, a:trea.marks) })
endfunction

function! trea#internal#core#update_marks(trea, marks) abort
  return s:Promise.resolve(a:trea.nodes)
        \.then({ ns -> s:AsyncLambda.map(ns, { v -> v.__key }) })
        \.then({ ks -> s:AsyncLambda.filter(a:marks, { v -> index(ks, v) isnot# -1 }) })
        \.then({ ms -> s:Lambda.let(a:trea, 'marks', ms) })
endfunction
