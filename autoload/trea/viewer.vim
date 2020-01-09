let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

let s:STATUS_NONE = g:trea#node#STATUS_NONE
let s:STATUS_COLLAPSED = g:trea#node#STATUS_COLLAPSED
let s:STATUS_EXPANDED = g:trea#node#STATUS_EXPANDED

function! trea#viewer#init(uri, provider, ...) abort
  setlocal buftype=nofile bufhidden=unload
  setlocal noswapfile nobuflisted nomodifiable
  setlocal filetype=trea

  nnoremap <buffer><silent> <Plug>(trea-redraw) :<C-u>call <SID>map_redraw()<CR><C-l>
  nnoremap <buffer><silent> <Plug>(trea-reload) :<C-u>call <SID>map_reload()<CR>
  nnoremap <buffer><silent> <Plug>(trea-expand) :<C-u>call <SID>map_expand()<CR>
  nnoremap <buffer><silent> <Plug>(trea-collapse) :<C-u>call <SID>map_collapse()<CR>
  nnoremap <buffer><silent> <Plug>(trea-reveal) :<C-u>call <SID>map_reveal()<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-on) :<C-u>call <SID>map_mark_on()<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-off) :<C-u>call <SID>map_mark_off()<CR>
  nnoremap <buffer><silent> <Plug>(trea-mark-toggle) :<C-u>call <SID>map_mark_toggle()<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-on) :call <SID>map_mark_on()<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-off) :call <SID>map_mark_off()<CR>
  vnoremap <buffer><silent> <Plug>(trea-mark-toggle) :call <SID>map_mark_toggle()<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-on) :<C-u>call trea#viewer#hidden_on()<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-off) :<C-u>call trea#viewer#hidden_off()<CR>
  nnoremap <buffer><silent> <Plug>(trea-hidden-toggle) :<C-u>call trea#viewer#hidden_toggle()<CR>
  nnoremap <buffer><silent> <Plug>(trea-filter) :<C-u>call <SID>map_filter()<CR>

  if !g:trea#viewer#disable_default_mappings
    nmap <buffer><nowait> <C-l> <Plug>(trea-redraw)
    nmap <buffer><nowait> <F5> <Plug>(trea-reload)
    nmap <buffer><nowait> l <Plug>(trea-expand)
    nmap <buffer><nowait> h <Plug>(trea-collapse)
    nmap <buffer><nowait> i <Plug>(trea-reveal)
    nmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    vmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    nmap <buffer><nowait> ! <Plug>(trea-hidden-toggle)
    nmap <buffer><nowait> f <Plug>(trea-filter)

  endif
  augroup trea_viewer_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd CursorMoved,CursorMovedI <buffer> let b:trea_cursor = getcurpos()
    autocmd BufReadCmd <buffer> nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
  augroup END

  let options = extend({
        \ 'renderer': trea#renderer#default#new(),
        \ 'comparator': trea#comparator#default#new(),
        \ 'reveal': [],
        \}, a:0 ? a:1 : {})

  call options.renderer.highlight()
  call options.renderer.syntax()

  let b:trea = {
        \ 'provider': a:provider,
        \ 'renderer': options.renderer,
        \ 'comparator': options.comparator,
        \ 'processing': 0,
        \ 'marks': [],
        \ 'hidden': 0,
        \ 'pattern': '',
        \}
  let trea = b:trea
  let winid = win_getid()
  return s:Promise.resolve(trea#node#new(a:provider.get_node(a:uri)))
        \.then({ n -> s:Lambda.pass(n, s:Lambda.let(trea, 'root', n)) })
        \.then({ n -> s:Lambda.pass(n, s:Lambda.let(trea, 'nodes', [n])) })
        \.then({ n -> trea#viewer#expand(n, { 'winid': winid }) })
        \.then({ -> trea#viewer#reveal(options.reveal, { 'winid': winid }) })
        \.catch(function('trea#lib#message#error'))
endfunction

function! trea#viewer#node(lnum, ...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let trea = s:get_trea_or_fail(bufnr)
  let index = trea.renderer.index(a:lnum)
  if index < 0 || index >= len(trea.nodes)
    return v:null
  endif
  return trea.nodes[index]
endfunction

function! trea#viewer#process(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  return trea#viewer#redraw(options)
        \.then({ -> trea#lib#spinner#start(bufnr) })
        \.then({ -> { -> trea#lib#spinner#stop(bufnr) }})
endfunction

function! trea#viewer#redraw(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  return trea.renderer.render(trea.nodes, trea.marks)
        \.then({ v -> trea#lib#buffer#replace(bufnr, v) })
endfunction

function! trea#viewer#reload(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if trea.processing
    return s:Promise.resolve()
  endif
  let trea.processing = 1
  let ns = {}
  return trea#viewer#process(options)
        \.then({ done -> s:Lambda.let(ns, 'done', done) })
        \.then({ -> trea#node#reload(a:node, trea.nodes, trea.provider, trea.comparator) })
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> ns.done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.finally({ -> s:Lambda.let(trea, 'processing', 0) })
endfunction

function! trea#viewer#expand(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if a:node.status is# s:STATUS_NONE
    " To improve UX, reload parent instead
    return trea#viewer#reload(trea#node#parent(a:node), options)
  elseif a:node.status is# s:STATUS_EXPANDED
    " To improve UX, reload instead
    return trea#viewer#reload(a:node, options)
  endif
  if trea.processing
    return s:Promise.resolve()
  endif
  let trea.processing = 1
  let ns = {}
  let cursor = s:WindowCursor.get_cursor(options.winid)
  return trea#viewer#process(options)
        \.then({ done -> s:Lambda.let(ns, 'done', done) })
        \.then({ -> trea#node#expand(a:node, trea.nodes, trea.provider, trea.comparator) })
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> ns.done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(trea#node#key(a:node), { "winid": options.winid, 'previous': cursor, "offset": 1 })})
        \.finally({ -> s:Lambda.let(trea, 'processing', 0) })
endfunction

function! trea#viewer#collapse(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \ 'strict': 0,
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if a:node == trea.root
    " To improve UX, root node should NOT be collapsed and reload instead.
    return trea#viewer#reload(a:node, options)
  elseif a:node.status isnot# s:STATUS_EXPANDED
    if !options.strict && a:node != trea.root
      return trea#viewer#collapse(trea#node#parent(a:node), options)
    endif
    " To improve UX, reload instead
    return trea#viewer#reload(a:node, options)
  endif
  if trea.processing
    return s:Promise.resolve()
  endif
  let trea.processing = 1
  let ns = {}
  let cursor = s:WindowCursor.get_cursor(options.winid)
  return trea#viewer#process(options)
        \.then({ done -> s:Lambda.let(ns, 'done', done) })
        \.then({ -> trea#node#collapse(a:node, trea.nodes, trea.provider) })
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> ns.done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(trea#node#key(a:node), { "winid": options.winid, 'previous': cursor })})
        \.finally({ -> s:Lambda.let(trea, 'processing', 0) })
endfunction

function! trea#viewer#reveal(key, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if trea.processing
    return s:Promise.resolve()
  endif
  let trea.processing = 1
  let ns = {}
  let cursor = s:WindowCursor.get_cursor(options.winid)
  return trea#viewer#process(options)
        \.then({ done -> s:Lambda.let(ns, 'done', done) })
        \.then({ -> trea#node#reveal(a:key, trea.nodes, trea.provider, trea.comparator) })
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> ns.done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(a:key, { "winid": options.winid, 'previous': cursor })})
        \.finally({ -> s:Lambda.let(trea, 'processing', 0) })
endfunction

function! trea#viewer#cursor(key, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \ 'offset': 0,
        \ 'strict': 0,
        \ 'previous': v:null
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let index = trea#node#index(a:key, trea.nodes)
  if index is# -1
    if !options.strict && a:key != trea#node#key(trea.root)
      return trea#viewer#cursor(a:key[:-2], options)
    endif
    return s:Promise.reject(printf('a node %s does not exist', a:key))
  endif
  let cursor = s:WindowCursor.get_cursor(options.winid)
  if options.previous is# v:null || options.previous == cursor
    call s:WindowCursor.set_cursor(
          \ options.winid,
          \ [index + 1 + options.offset, cursor[1]],
          \)
  endif
  return s:Promise.resolve()
endfunction

function! trea#viewer#mark_on(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let key = trea#node#key(a:node)
  if index(trea.marks, key) is# -1
    call add(trea.marks, key)
    return trea#viewer#redraw(options)
  endif
  return s:Promise.resolve()
endfunction

function! trea#viewer#mark_off(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let key = trea#node#key(a:node)
  let index = index(trea.marks, key)
  if index isnot# -1
    call remove(trea.marks, index)
    return trea#viewer#redraw(options)
  endif
  return s:Promise.resolve()
endfunction

function! trea#viewer#mark_toggle(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let key = trea#node#key(a:node)
  if index(trea.marks, key) is# -1
    call trea#viewer#mark_on(a:node, options)
  else
    call trea#viewer#mark_off(a:node, options)
  endif
endfunction

function! trea#viewer#hidden_on(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if !trea.hidden
    let trea.hidden = 1
    return trea#viewer#reload(trea.root, options)
  endif
  return s:Promise.resolve()
endfunction

function! trea#viewer#hidden_off(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if trea.hidden
    let trea.hidden = 0
    return trea#viewer#reload(trea.root, options)
  endif
  return s:Promise.resolve()
endfunction

function! trea#viewer#hidden_toggle(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if trea.hidden
    return trea#viewer#hidden_off(options)
  else
    return trea#viewer#hidden_on(options)
  endif
endfunction

function! trea#viewer#filter(pattern, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if trea.pattern !=# a:pattern
    let trea.pattern = a:pattern
    return trea#viewer#reload(trea.root, options)
  endif
  return s:Promise.resolve()
endfunction

function! s:get_trea_or_fail(bufnr) abort
  let trea = getbufvar(a:bufnr, 'trea', v:null)
  if trea is# v:null
    throw printf(
          \ "[trea] no 'trea' found in the buffer %s (%d)",
          \ bufname(a:bufnr),
          \ a:bufnr,
          \)
  endif
  return trea
endfunction

function! s:update_nodes(bufnr, nodes) abort
  let trea = s:get_trea_or_fail(a:bufnr)
  let trea.marks = []
  let trea.nodes = copy(a:nodes)
  let Hidden = trea.hidden
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || !v.hidden }
  let Filter = empty(trea.pattern)
        \ ? { -> 1 }
        \ : { v -> v.status is# s:STATUS_EXPANDED || v.name =~ trea.pattern }
  return s:Promise.resolve(trea.nodes)
        \.then({ ns -> trea#lib#gradual#filter(ns, Hidden) })
        \.then({ ns -> trea#lib#gradual#filter(ns, Filter) })
        \.then({ ns -> s:Lambda.let(trea, 'nodes', ns) })
endfunction

function! s:map_redraw() abort
  call trea#viewer#redraw()
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:map_reload() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#reload(node)
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:map_expand() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#expand(node)
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:map_collapse() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#collapse(node)
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:map_reveal() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  let trea = s:get_trea_or_fail(bufnr('%'))
  call inputsave()
  try
    let path = input(
          \ "Please input a relative path to reveal: ",
          \ join(trea#node#key(node), '/') . '/',
          \)
    if empty(path)
      echo "Cancelled"
      return
    endif
    call trea#viewer#reveal(split(path, '/'))
        \.catch(function('trea#lib#message#error'))
  finally
    call inputrestore()
  endtry
endfunction

function! s:map_mark_on() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#mark_on(node)
endfunction

function! s:map_mark_off() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#mark_off(node)
endfunction

function! s:map_mark_toggle() abort
  let node = trea#viewer#node(line('.'))
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  call trea#viewer#mark_toggle(node)
endfunction

function! s:map_filter() abort
  let trea = s:get_trea_or_fail(bufnr('%'))
  call inputsave()
  try
    let pattern = input(
          \ "Please input a pattern: ",
          \ trea.pattern,
          \)
    call trea#viewer#filter(pattern)
        \.catch(function('trea#lib#message#error'))
  finally
    call inputrestore()
  endtry
endfunction

function! s:BufReadCmd() abort
  let trea = s:get_trea_or_fail(bufnr('%'))
  let winid = win_getid()
  let cursor = get(b:, 'trea_cursor', getcurpos())
  call trea.renderer.syntax()
  call trea#viewer#redraw()
        \.then({ -> s:WindowCursor.set_cursor(winid, cursor[1:2]) })
        \.then({ -> trea#viewer#reload(trea.root) })
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:ColorScheme() abort
  let trea = s:get_trea_or_fail(bufnr('%'))
  call trea.renderer.highlight()
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_default_mappings': 0,
      \})
