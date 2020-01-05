let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

let s:STATUS_COLLAPSED = g:trea#node#STATUS_COLLAPSED
let s:STATUS_EXPANDED = g:trea#node#STATUS_EXPANDED

function! trea#viewer#init(provider, ...) abort
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

  if !g:trea#viewer#disable_default_mappings
    nmap <buffer><nowait> <C-l> <Plug>(trea-redraw)
    nmap <buffer><nowait> <F5> <Plug>(trea-reload)
    nmap <buffer><nowait> l <Plug>(trea-expand)
    nmap <buffer><nowait> h <Plug>(trea-collapse)
    nmap <buffer><nowait> i <Plug>(trea-reveal)
    nmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    vmap <buffer><nowait> - <Plug>(trea-mark-toggle)
  endif

  augroup trea_viewer_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd CursorMoved,CursorMovedI <buffer> let b:trea_cursor = getcurpos()
    autocmd BufReadCmd <buffer> nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
  augroup END

  let root = trea#node#new(a:provider.get_root())
  let options = extend({
        \ 'renderer': trea#renderer#default#new(),
        \ 'comparator': trea#comparator#default#new(),
        \ 'reveal': root.key,
        \}, a:0 ? a:1 : {})

  call options.renderer.highlight()
  call options.renderer.syntax()

  let b:trea = {
        \ 'provider': a:provider,
        \ 'renderer': options.renderer,
        \ 'comparator': options.comparator,
        \ 'root': root,
        \ 'nodes': [root],
        \ 'marks': [],
        \}
  let winid = win_getid()
  return trea#viewer#expand(root, { 'winid': winid })
       \.then({ -> trea#viewer#reveal(options.reveal, { 'winid': winid }) })
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

function! trea#viewer#process(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let a:node.__processing = 1
  call trea#viewer#redraw(options)
  call trea#lib#spinner#start({
        \ 'bufnr': bufnr,
        \})
  return { -> s:Lambda.void(
        \   trea#lib#spinner#stop({ 'bufnr': bufnr }),
        \   s:Lambda.let(a:node, '__processing', 0),
        \)}
endfunction

function! trea#viewer#redraw(...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let content = trea.renderer.render(trea.nodes, trea.marks)
  call trea#lib#buffer#replace(bufnr, content)
endfunction

function! trea#viewer#reload(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let Done = trea#viewer#process(a:node, options)
  return trea#node#reload(a:node, trea.nodes, trea.provider, trea.comparator)
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> Done() })
        \.then({ -> trea#viewer#redraw(options) })
endfunction

function! trea#viewer#expand(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if !a:node.branch
    " To improve UX, reload parent instead
    return trea#viewer#reload(trea#node#parent(a:node), options)
  elseif trea#node#status(a:node) is# s:STATUS_EXPANDED
    " To improve UX, reload instead
    return trea#viewer#reload(a:node, options)
  endif
  let Done = trea#viewer#process(a:node, options)
  return trea#node#expand(a:node, trea.nodes, trea.provider, trea.comparator)
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> Done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(a:node.key, { "winid": options.winid, "offset": 1 })})
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
  elseif trea#node#status(a:node) is# s:STATUS_COLLAPSED
    if !options.strict && a:node != trea.root
      return trea#viewer#collapse(trea#node#parent(a:node), options)
    endif
    " To improve UX, reload instead
    return trea#viewer#reload(a:node, options)
  endif
  let Done = trea#viewer#process(a:node, options)
  return trea#node#collapse(a:node, trea.nodes, trea.provider)
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> Done() })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(a:node.key, { "winid": options.winid })})
endfunction

function! trea#viewer#reveal(key, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \ 'strict': 0,
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  return trea#node#reveal(a:key, trea.nodes, trea.provider, trea.comparator)
        \.then({ v -> s:update_nodes(bufnr, v) })
        \.then({ -> trea#viewer#redraw(options) })
        \.then({ -> trea#viewer#cursor(a:key, { "winid": options.winid })})
endfunction

function! trea#viewer#cursor(key, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \ 'offset': 0,
        \ 'strict': 0,
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let index = trea#node#index(a:key, trea.nodes)
  if index is# -1
    if !options.strict && a:key != trea.root.key
      return trea#viewer#cursor(a:key[:-2], options)
    endif
    return s:Promise.reject(printf('a node %s does not exist', a:key))
  endif
  let cursor = s:WindowCursor.get_cursor(options.winid)
  call s:WindowCursor.set_cursor(
        \ options.winid,
        \ [index + 1 + options.offset, cursor[1]],
        \)
  return s:Promise.resolve()
endfunction

function! trea#viewer#mark_on(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if index(trea.marks, a:node.key) is# -1
    call add(trea.marks, a:node.key)
    call trea#viewer#redraw(options)
  endif
endfunction

function! trea#viewer#mark_off(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  let index = index(trea.marks, a:node.key)
  if index isnot# -1
    call remove(trea.marks, index)
    call trea#viewer#redraw(options)
  endif
endfunction

function! trea#viewer#mark_toggle(node, ...) abort
  let options = extend({
        \ 'winid': win_getid(),
        \}, a:0 ? a:1 : {})
  let bufnr = winbufnr(options.winid)
  let trea = s:get_trea_or_fail(bufnr)
  if index(trea.marks, a:node.key) is# -1
    call trea#viewer#mark_on(a:node, options)
  else
    call trea#viewer#mark_off(a:node, options)
  endif
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
  let trea.nodes = a:nodes
  let trea.marks = []
endfunction

function! s:map_redraw() abort
  call trea#viewer#redraw()
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
    let uri = input(
          \ "Please input a URI to reveal: ",
          \ trea.provider.get_uri(node.key),
          \)
    if empty(uri)
      echo "Cancelled"
      return
    endif
    call trea#viewer#reveal(trea.provider.get_key(uri))
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

function! s:BufReadCmd() abort
  let trea = s:get_trea_or_fail(bufnr('%'))
  let cursor = get(b:, 'trea_cursor', getcurpos())
  call trea.renderer.syntax()
  call trea#viewer#redraw()
  call setpos('.', cursor)
  call trea#viewer#reload(trea.root)
        \.catch(function('trea#lib#message#error'))
endfunction

function! s:ColorScheme() abort
  let trea = s:get_trea_or_fail(bufnr('%'))
  call trea.renderer.highlight()
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_default_mappings': 0,
      \})
