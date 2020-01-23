let s:Lambda = vital#trea#import('Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:Prompt = vital#trea#import('Prompt')
let s:Path = vital#trea#import('System.Filepath')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

let s:clipboard = []

let s:STATUS_EXPANDED = g:trea#internal#node#STATUS_EXPANDED


function! trea#scheme#file#mapping#init() abort
  nnoremap <buffer><silent> <Plug>(trea-cd:cd)            :<C-u>call <SID>call('cd', 'cd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-cd:lcd)           :<C-u>call <SID>call('cd', 'lcd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-cd:tcd)           :<C-u>call <SID>call('cd', 'tcd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:system)      :<C-u>call <SID>call('open_system')<CR>
  nnoremap <buffer><silent> <Plug>(trea-mkfile)           :<C-u>call <SID>call('mkfile')<CR>
  nnoremap <buffer><silent> <Plug>(trea-mkdir)            :<C-u>call <SID>call('mkdir')<CR>
  nnoremap <buffer><silent> <Plug>(trea-move)             :<C-u>call <SID>call('move')<CR>
  nnoremap <buffer><silent> <Plug>(trea-clipboard-copy)   :<C-u>call <SID>call('clipboard_copy')<CR>
  nnoremap <buffer><silent> <Plug>(trea-clipboard-paste)  :<C-u>call <SID>call('clipboard_paste')<CR>
  nnoremap <buffer><silent> <Plug>(trea-clipboard-clear)  :<C-u>call <SID>call('clipboard_clear')<CR>
  nnoremap <buffer><silent> <Plug>(trea-trash)            :<C-u>call <SID>call('trash', 0)<CR>
  nnoremap <buffer><silent> <Plug>(trea-remove)           :<C-u>call <SID>call('remove', 0)<CR>
  nnoremap <buffer><silent> <Plug>(trea-trash:immediate)  :<C-u>call <SID>call('trash', 1)<CR>
  nnoremap <buffer><silent> <Plug>(trea-remove:immediate) :<C-u>call <SID>call('remove', 1)<CR>

  nmap <buffer> <Plug>(trea-cd) <Plug>(trea-cd:tcd)

  if !g:trea#internal#mapping#disable_default_mappings
    nmap <buffer><nowait> x <Plug>(trea-open:system)
    nmap <buffer><nowait> N <Plug>(trea-mkfile)
    nmap <buffer><nowait> K <Plug>(trea-mkdir)
    nmap <buffer><nowait> m <Plug>(trea-move)
    nmap <buffer><nowait> c <Plug>(trea-clipboard-copy)
    nmap <buffer><nowait> p <Plug>(trea-clipboard-paste)
    nmap <buffer><nowait> d <Plug>(trea-trash)
  endif
endfunction

function! s:call(name, ...) abort
  let Fn = funcref(printf('s:map_%s', a:name))
  let r = call('trea#helper#call', [Fn] + a:000)
  if s:Promise.is_promise(r)
    r.catch({ e -> trea#lib#message#error(e) })
  endif
endfunction

function! s:map_cd(helper, command) abort
  let path = a:helper.get_root_node()._path
  if a:command ==# 'tcd' && !exists(':tcd')
    let winid = win_getid()
    silent execute printf(
          \ 'keepalt keepjumps %d,%dwindo lcd %s',
          \ 1, winnr('$'), fnameescape(path),
          \)
    call win_gotoid(winid)
  else
    execute a:command fnameescape(path)
  endif
  return s:Promise.resolve()
endfunction

function! s:map_open_system(helper) abort
  let node = a:helper.get_cursor_node()
  let node.__processing += 1
  return trea#lib#shutil#open(node._path, a:helper.trea.source.token)
        \.then({ -> trea#lib#message#info(printf('%s has opened', node._path)) })
        \.finally({ -> s:Lambda.let(node, '__processing', node.__processing - 1) })
endfunction

function! s:map_mkfile(helper) abort
  let name = s:Prompt.ask('New file: ', '', 'file')
  if empty(name)
    return s:Promise.reject('Cancelled')
  endif
  let node = a:helper.get_cursor_node()
  let node = node.status isnot# s:STATUS_EXPANDED ? node.__owner : node
  let path = s:Path.join(node._path, name)
  let key = node.__key + [name]
  let cursor = a:helper.get_cursor()
  return trea#lib#shutil#mkfile(path, a:helper.trea.source.token)
        \.then({ -> a:helper.reload(node) })
        \.then({ -> a:helper.redraw() })
        \.then({ -> a:helper.focus_node(key, { 'previous': cursor }) })
endfunction

function! s:map_mkdir(helper) abort
  let name = s:Prompt.ask('New directory: ', '', 'file')
  if empty(name)
    return s:Promise.reject('Cancelled')
  endif
  let node = a:helper.get_cursor_node()
  let node = node.status isnot# s:STATUS_EXPANDED ? node.__owner : node
  let path = s:Path.join(node._path, name)
  let key = node.__key + [name]
  let winid = win_getid()
  let cursor = s:WindowCursor.get_cursor(winid)
  return trea#lib#shutil#mkdir(path, a:helper.trea.source.token)
        \.then({ -> a:helper.reload(node) })
        \.then({ -> a:helper.redraw() })
        \.then({ -> a:helper.focus_node(key, { 'previous': cursor }) })
endfunction

function! s:map_move(helper) abort
  let nodes = a:helper.get_selected_nodes()
  let token = a:helper.trea.source.token
  let ps = []
  for node in nodes
    let src = node._path
    let dst = s:Prompt.ask(
          \ printf('Move: %s -> ', src),
          \ src,
          \ isdirectory(src) ? 'dir' : 'file',
          \)
    if empty(dst) || src ==# dst
      continue
    endif
    call add(ps, trea#lib#shutil#move(src, dst, token))
  endfor
  return s:Promise.all(ps)
        \.then({ -> a:helper.reload(node, a:helper.get_root_node()) })
        \.then({ -> a:helper.redraw() })
        \.then({ -> trea#lib#message#info(printf('%d items are moved', len(ps))) })
endfunction

function! s:map_clipboard_copy(helper) abort
  let nodes = a:helper.get_selected_nodes()
  let a:helper.trea.marks = []
  let s:clipboard = map(
        \ copy(nodes),
        \ { _, v -> v._path },
        \)
  return s:Promise.resolve()
        \.then({ -> a:helper.redraw() })
        \.then({ -> trea#lib#message#info(printf('%d items are stacked', len(ps))) })
endfunction

function! s:map_clipboard_paste(trea) abort
  if empty(s:clipboard)
    return s:Promise.reject("Nothing to paste")
  endif
  let node = trea#core#get_cursor_node(a:trea)
  let node = node.status isnot# s:STATUS_EXPANDED ? node.__owner : node
  let token = a:trea.source.token
  let ps = []
  for src in s:clipboard
    let dst = s:Path.join(node._path, fnamemodify(src, ':t'))
    call trea#lib#message#info(printf("Copy %s -> %s", src, dst))
    call add(ps, trea#lib#shutil#copy(src, dst, token))
  endfor
  return s:Promise.all(ps)
        \.then({ -> trea#core#reload(a:trea, a:trea.root) })
        \.then({ -> trea#lib#message#info(printf('%d items are copied', len(ps))) })
endfunction

function! s:map_clipboard_clear(trea) abort
  let s:clipboard = []
endfunction

function! s:map_trash(trea, immediate) abort
  let nodes = trea#core#get_selected_nodes(a:trea)
  let paths = map(copy(nodes), { _, v -> v._path })
  if !a:immediate
    let prompt = printf("The follwoing %d files will be trached", len(paths))
    for path in paths[:5]
      let prompt .= "\n" . path
    endfor
    if len(paths) > 5
      let prompt .= "\n..."
    endif
    let prompt .= "\nAre you sure to continue (Y[es]/no): "
    if !s:Prompt.confirm(prompt)
      return s:Promise.reject("Cancelled")
    endif
  endif
  let token = a:trea.source.token
  let ps = []
  for path in paths
    call trea#lib#message#info(printf("Delete %s", path))
    call add(ps, trea#lib#shutil#trash(path, token))
  endfor
  return s:Promise.all(ps)
        \.then({ -> trea#core#reload(a:trea, a:trea.root) })
        \.then({ -> trea#lib#message#info(printf('%d items are trashed', len(ps))) })
endfunction

function! s:map_remove(trea, immediate) abort
  let nodes = trea#core#get_selected_nodes(a:trea)
  let paths = map(copy(nodes), { _, v -> v._path })
  if !a:immediate
    let prompt = printf("The follwoing %d files will be removed", len(paths))
    for path in paths[:5]
      let prompt .= "\n" . path
    endfor
    if len(paths) > 5
      let prompt .= "\n..."
    endif
    let prompt .= "\nAre you sure to continue (Y[es]/no): "
    if !s:Prompt.confirm(prompt)
      return s:Promise.reject("Cancelled")
    endif
  endif
  let token = a:trea.source.token
  let ps = []
  for path in paths
    call trea#lib#message#info(printf("Delete %s", path))
    call add(ps, trea#lib#shutil#remove(path, token))
  endfor
  return s:Promise.all(ps)
        \.then({ -> trea#core#reload(a:trea, a:trea.root) })
        \.then({ -> trea#lib#message#info(printf('%d items are removed', len(ps))) })
endfunction
