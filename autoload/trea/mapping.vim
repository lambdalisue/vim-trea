let s:Config = vital#trea#import('Config')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

function! trea#mapping#init() abort
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
  nnoremap <buffer><silent> <Plug>(trea-open-select)   :<C-u>call <SID>invoke('open', 'select')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-edit)     :<C-u>call <SID>invoke('open', 'edit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-split)    :<C-u>call <SID>invoke('open', 'split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-vsplit)   :<C-u>call <SID>invoke('open', 'vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-tabedit)  :<C-u>call <SID>invoke('open', 'tabedit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-above)    :<C-u>call <SID>invoke('open', 'leftabove split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-left)     :<C-u>call <SID>invoke('open', 'leftabove vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-below)    :<C-u>call <SID>invoke('open', 'rightbelow split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-right)    :<C-u>call <SID>invoke('open', 'rightbelow vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-top)      :<C-u>call <SID>invoke('open', 'topleft split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-leftest)  :<C-u>call <SID>invoke('open', 'topleft vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-bottom)   :<C-u>call <SID>invoke('open', 'botright split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open-rightest) :<C-u>call <SID>invoke('open', 'botright vsplit')<CR>

  nmap <buffer><silent><expr> <Plug>(trea-enter-or-open) trea#mapping#is_branch()
        \ ? "\<Plug>(trea-enter)"
        \ : "\<Plug>(trea-open)"
  nmap <buffer><silent><expr> <Plug>(trea-expand-or-open) trea#mapping#is_branch()
        \ ? "\<Plug>(trea-expand)"
        \ : "\<Plug>(trea-open)"
  nmap <buffer><silent> <Plug>(trea-open) <Plug>(trea-open-edit)

  if !g:trea#mapping#disable_default_mappings
    nmap <buffer><nowait> <C-c> <Plug>(trea-cancel)
    nmap <buffer><nowait> <C-l> <Plug>(trea-redraw)
    nmap <buffer><nowait> <F5> <Plug>(trea-reload)
    nmap <buffer><nowait> <Return> <Plug>(trea-enter-or-open)
    nmap <buffer><nowait> <Backspace> <Plug>(trea-leave)
    nmap <buffer><nowait> l <Plug>(trea-expand-or-open)
    nmap <buffer><nowait> h <Plug>(trea-collapse)
    nmap <buffer><nowait> i <Plug>(trea-reveal)
    nmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    vmap <buffer><nowait> - <Plug>(trea-mark-toggle)
    nmap <buffer><nowait> ! <Plug>(trea-hidden-toggle)
    nmap <buffer><nowait> f <Plug>(trea-filter)
  endif
endfunction

function! trea#mapping#is_branch() abort
  let trea = trea#core#get()
  if trea is# v:null
    call trea#lib#message#error("the buffer has not properly initialized")
    return
  endif
  let node = trea#core#node(trea)
  if node is# v:null
    call trea#lib#message#error("no node found on a cursor line")
    return
  endif
  return node.status isnot# 0
endfunction

function! s:invoke(name, ...) abort
  let trea = trea#core#get()
  if trea is# v:null
    call trea#lib#message#error("the buffer has not properly initialized")
    return
  endif
  call call(printf('s:map_%s', a:name), [trea] + a:000)
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

function! s:map_open(trea, opener) abort
  let node = trea#core#node(a:trea)
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#lib#buffer#open(node.uri, {
        \ 'opener': a:opener,
        \})
endfunction

call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_default_mappings': 0,
      \})
