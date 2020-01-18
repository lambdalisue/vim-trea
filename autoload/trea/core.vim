let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')
let s:CancellationTokenSource = vital#trea#import('Async.CancellationTokenSource')

let s:STATUS_NONE = g:trea#node#STATUS_NONE
let s:STATUS_COLLAPSED = g:trea#node#STATUS_COLLAPSED
let s:STATUS_EXPANDED = g:trea#node#STATUS_EXPANDED

function! trea#core#init(uri, provider, ...) abort
  setlocal buftype=nofile bufhidden=unload
  setlocal noswapfile nobuflisted nomodifiable
  setlocal signcolumn=yes:1
  setlocal filetype=trea

  nnoremap <buffer><silent> <Plug>(trea-cancel)        :<C-u>call <SID>invoke('cancel')<CR>
  nnoremap <buffer><silent> <Plug>(trea-redraw)        :<C-u>call <SID>invoke('redraw')<CR>
  nnoremap <buffer><silent> <Plug>(trea-reload)        :<C-u>call <SID>invoke('reload')<CR>
  nnoremap <buffer><silent> <Plug>(trea-expand)        :<C-u>call <SID>invoke('expand')<CR>
  nnoremap <buffer><silent> <Plug>(trea-collapse)      :<C-u>call <SID>invoke('collapse')<CR>
  nnoremap <buffer><silent> <Plug>(trea-reveal)        :<C-u>call <SID>invoke('reveal')<CR>
  nnoremap <buffer><silent> <Plug>(trea-enter)         :<C-u>call <SID>invoke('enter')<CR>
  nnoremap <buffer><silent> <Plug>(trea-leave)         :<C-u>call <SID>invoke('leave')<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-on)       :<C-u>call <SID>invoke('mark_on')<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-off)      :<C-u>call <SID>invoke('mark_off')<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-toggle)   :<C-u>call <SID>invoke('mark_toggle')<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-on)     :<C-u>call <SID>invoke('hidden_on')<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-off)    :<C-u>call <SID>invoke('hidden_off')<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-toggle) :<C-u>call <SID>invoke('hidden_toggle')<CR>
  nnoremap <buffer><silent> <Plug>(trea-filter)        :<C-u>call <SID>invoke('filter')<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-on)       :call <SID>invoke('mark_on')<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-off)      :call <SID>invoke('mark_off')<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-toggle)   :call <SID>invoke('mark_toggle')<CR>

  if !g:trea#core#disable_default_mappings
    nmap <buffer><nowait> <C-c> <Plug>(trea-cancel)
    nmap <buffer><nowait> <C-l> <Plug>(trea-redraw)
    nmap <buffer><nowait> <F5> <Plug>(trea-reload)
    nmap <buffer><nowait> <Return> <Plug>(trea-enter)
    nmap <buffer><nowait> <Backspace> <Plug>(trea-leave)
    nmap <buffer><nowait> l <Plug>(trea-expand)
    nmap <buffer><nowait> h <Plug>(trea-collapse)
    nmap <buffer><nowait> i <Plug>(trea-reveal)
    nmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    vmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    nmap <buffer><nowait> ! <Plug>(trea-hidden-toggle)
    nmap <buffer><nowait> f <Plug>(trea-filter)
  endif

  augroup trea_core_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd CursorMoved,CursorMovedI <buffer> let b:trea_cursor = getcurpos()
    autocmd BufReadCmd <buffer> nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
  augroup END

  let options = extend({
        \ 'reveal': [],
        \ 'comparator': trea#comparator#default#new(),
        \}, a:0 ? a:1 : {},
        \)
  let trea = {
        \ 'bufnr': bufnr('%'),
        \ 'source': s:CancellationTokenSource.new(),
        \ 'provider': a:provider,
        \ 'comparator': options.comparator,
        \ 'marks': [],
        \ 'hidden': 0,
        \ 'pattern': '',
        \}
  call setbufvar(trea.bufnr, 'trea', trea)
  call trea#spinner#start(trea.bufnr)
  call trea#renderer#highlight()
  call trea#renderer#syntax()

  let root = trea#node#new(a:provider.get_node(a:uri))
  let trea.root = root
  let trea.nodes = [root]
  let b:trea = trea

  return s:Promise.resolve()
        \.then({ -> trea#core#expand(trea, trea.root) })
        \.then({ -> trea#core#reveal(trea, options.reveal) })
endfunction

function! trea#core#get(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  return getbufvar(bufnr, 'trea', v:null)
endfunction

function! trea#core#node(trea, ...) abort
  if a:0 is# 0
    let info = getbufinfo(a:trea.bufnr)
    if empty(info)
      return v:null
    endif
    let lnum = info[0].lnum
  else
    let lnum = a:1
  endif
  return get(a:trea.nodes, lnum - 1, v:null)
endfunction

function! trea#core#cancel(trea) abort
  call a:trea.source.cancel()
  let a:trea.source = s:CancellationTokenSource.new()
  return trea#core#redraw(a:trea)
endfunction

function! trea#core#redraw(trea) abort
  return trea#renderer#render(a:trea.nodes, a:trea.marks)
        \.then({ v -> trea#lib#buffer#replace(a:trea.bufnr, v) })
endfunction

function! trea#core#cursor(winid, trea, key, ...) abort
  let options = extend({
        \ 'offset': 0,
        \ 'previous': v:null
        \}, a:0 ? a:1 : {})
  let index = trea#node#index(a:key, a:trea.nodes)
  if index is# -1
    if a:key != trea#node#key(a:trea.root)
      return trea#core#cursor(a:winid, a:trea, a:key[:-2], options)
    endif
    return s:Promise.reject(printf('a node %s does not exist', a:key))
  endif
  let cursor = s:WindowCursor.get_cursor(a:winid)
  if options.previous is# v:null || options.previous == cursor
    call s:WindowCursor.set_cursor(a:winid, [index + 1 + options.offset, cursor[1]])
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#reload(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#node#reload(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#expand(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#node#expand(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#collapse(trea, node) abort
  return s:Promise.resolve()
        \.then({ -> trea#node#collapse(
        \   a:node,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#reveal(trea, key) abort
  return s:Promise.resolve()
        \.then({ -> trea#node#reveal(
        \   a:key,
        \   a:trea.nodes,
        \   a:trea.provider,
        \   a:trea.comparator,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ v -> s:update_nodes(a:trea, v) })
        \.then({ -> trea#core#redraw(a:trea) })
endfunction

function! trea#core#enter(trea, node) abort
  if a:node.status is# s:STATUS_NONE
    return s:Promise.reject()
  endif
  return s:Promise.resolve(a:node)
        \.then({ n -> s:enter(a:trea, n.uri) })
endfunction

function! trea#core#leave(trea) abort
  return s:Promise.resolve(a:trea.root)
        \.then({ root -> trea#node#parent(
        \   root,
        \   a:trea.provider,
        \   a:trea.source.token,
        \ )
        \})
        \.then({ n -> s:enter(a:trea, n.uri) })
endfunction

function! trea#core#mark_on(trea, node) abort
  let key = trea#node#key(a:node)
  if index(a:trea.marks, key) is# -1
    call add(a:trea.marks, key)
    return trea#core#redraw(a:trea)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#mark_off(trea, node) abort
  let key = trea#node#key(a:node)
  let index = index(a:trea.marks, key)
  if index isnot# -1
    call remove(a:trea.marks, index)
    return trea#core#redraw(a:trea)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#mark_toggle(trea, node) abort
  let key = trea#node#key(a:node)
  if index(a:trea.marks, key) is# -1
    return trea#core#mark_on(a:trea, a:node)
  endif
  return trea#core#mark_off(a:trea, a:node)
endfunction

function! trea#core#hidden_on(trea) abort
  if !a:trea.hidden
    let a:trea.hidden = 1
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#hidden_off(trea) abort
  if a:trea.hidden
    let a:trea.hidden = 0
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! trea#core#hidden_toggle(trea) abort
  if a:trea.hidden
    return trea#core#hidden_off(a:trea)
  endif
  return trea#core#hidden_on(a:trea)
endfunction

function! trea#core#filter(trea, pattern) abort
  if a:trea.pattern !=# a:pattern
    let a:trea.pattern = a:pattern
    return trea#core#reload(a:trea, a:trea.root)
  endif
  return s:Promise.resolve()
endfunction

function! s:BufReadCmd() abort
  let trea = trea#core#get()
  let winid = win_getid()
  let cursor = get(b:, 'trea_cursor', getcurpos())
  call trea#renderer#syntax()
  call trea#core#redraw(trea)
        \.then({ -> s:WindowCursor.set_cursor(winid, cursor[1:2]) })
        \.then({ -> trea#core#reload(trea, trea.root) })
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:ColorScheme() abort
  let trea = trea#core#get()
  call trea#renderer#highlight()
endfunction

function! s:update_nodes(trea, nodes) abort
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
        \.then({ -> s:update_marks(a:trea, a:trea.marks) })
endfunction

function! s:update_marks(trea, marks) abort
  return s:Promise.resolve(a:trea.nodes)
        \.then({ ns -> s:AsyncLambda.map(ns, { v -> v.__key }) })
        \.then({ ks -> s:AsyncLambda.filter(a:marks, { v -> index(ks, v) isnot# -1 }) })
        \.then({ ms -> s:Lambda.let(a:trea, 'marks', ms) })
endfunction

function! s:enter(trea, uri) abort
  noautocmd execute printf('edit trea://%s', a:uri)
  return trea#core#init(a:uri, a:trea.provider, {
        \ 'comparator': a:trea.comparator,
        \})
endfunction

function! s:invoke(name) abort
  let trea = trea#core#get()
  if trea is# v:null
    call trea#lib#message#error("the buffer has not properly initialized")
    return
  endif
  call call(printf('s:map_%s', a:name), [trea])
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:map_cancel(trea) abort
  return trea#core#cancel(a:trea)
endfunction

function! s:map_redraw(trea) abort
  return trea#core#redraw(a:trea)
endfunction

function! s:map_reload(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#core#reload(a:trea, node)
endfunction

function! s:map_expand(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  let winid = win_getid()
  let cursor = s:WindowCursor.get_cursor(winid)
  return trea#core#expand(a:trea, node)
        \.then({ -> trea#core#cursor(
        \   winid,
        \   a:trea,
        \   trea#node#key(node),
        \   { 'previous': cursor, 'offset': 1 },
        \ )
        \})
endfunction

function! s:map_collapse(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  let winid = win_getid()
  let cursor = s:WindowCursor.get_cursor(winid)
  return trea#core#collapse(a:trea, node)
        \.then({ -> trea#core#cursor(
        \   winid,
        \   a:trea,
        \   trea#node#key(node),
        \   { 'previous': cursor },
        \ )
        \})
endfunction

function! s:map_reveal(trea) abort
  let node = trea#core#node(a:trea)
  let path = node is# v:null
        \ ? ''
        \ : join(trea#node#key(node), '/') . '/'
  call inputsave()
  try
    redraw
    let path = input("Please input a relative path to reveal: ", path)
    if empty(path)
      return s:Promise.reject("Cancelled")
    endif
    let key = split(path, '/')
    let winid = win_getid()
    let cursor = s:WindowCursor.get_cursor(winid)
    return trea#core#reveal(a:trea, key)
        \.then({ -> trea#core#cursor(
        \   winid,
        \   a:trea,
        \   key,
        \   { 'previous': cursor },
        \ )
        \})
  finally
    call inputrestore()
  endtry
endfunction

function! s:map_enter(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#core#enter(a:trea, node)
endfunction

function! s:map_leave(trea) abort
  return trea#core#leave(a:trea)
endfunction

function! s:map_mark_on(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#core#mark_on(a:trea, node)
endfunction

function! s:map_mark_off(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#core#mark_off(a:trea, node)
endfunction

function! s:map_mark_toggle(trea) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#core#mark_toggle(a:trea, node)
endfunction

function! s:map_hidden_on(trea) abort
  return trea#core#hidden_on(a:trea)
endfunction

function! s:map_hidden_off(trea) abort
  return trea#core#hidden_off(a:trea)
endfunction

function! s:map_hidden_toggle(trea) abort
  return trea#core#hidden_toggle(a:trea)
endfunction

function! s:map_filter(trea) abort
  call inputsave()
  try
    redraw
    let input = input("Please input a pattern: ", a:trea.pattern)
    return trea#core#filter(a:trea, input)
  finally
    call inputrestore()
  endtry
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_default_mappings': 0,
      \})
