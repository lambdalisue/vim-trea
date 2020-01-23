let s:Lambda = vital#trea#import('Lambda')
let s:AsyncLambda = vital#trea#import('Async.Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')
let s:CancellationTokenSource = vital#trea#import('Async.CancellationTokenSource')

function! trea#helper#new() abort
  if !exists('b:trea')
    throw 'b:trea is not found in the current buffer'
  endif
  let helper = extend({
        \ 'trea': b:trea,
        \ 'bufnr': bufnr('%'),
        \ 'winid': win_getid(),
        \ 'STATUS_NONE': g:trea#internal#node#STATUS_NONE,
        \ 'STATUS_COLLAPSED': g:trea#internal#node#STATUS_COLLAPSED,
        \ 'STATUS_EXPANDED': g:trea#internal#node#STATUS_EXPANDED,
        \}, s:helper)
  lockvar 2 helper
  return helper
endfunction

function! trea#helper#call(fn, ...) abort
  if !exists('b:trea')
    throw 'b:trea is not found in the current buffer'
  endif
  let helper = trea#helper#new()
  return call(a:fn, [helper] + a:000)
endfunction

let s:helper = {}


" Sync
function! s:helper.get_root_node() abort
  return self.trea.root
endfunction

function! s:helper.get_cursor_node() abort
  let cursor = self.get_cursor()
  return get(self.trea.nodes, cursor[0] - 1, v:null)
endfunction

function! s:helper.get_marked_nodes() abort
  let ms = self.trea.marks
  return filter(
        \ copy(self.trea.nodes),
        \ { _, v -> index(ms, v.__key) isnot# -1 },
        \)
endfunction

function! s:helper.get_selected_nodes() abort
  if empty(self.trea.marks)
    return [self.get_cursor_node()]
  endif
  return self.get_marked_nodes()
endfunction

function! s:helper.get_cursor() abort
  return s:WindowCursor.get_cursor(self.winid)
endfunction

function! s:helper.set_cursor(cursor) abort
  call s:WindowCursor.set_cursor(self.winid, a:cursor)
endfunction

function! s:helper.is_marked(node) abort
  return index(self.trea.marks, a:node.__key) is# -1
endfunction

function! s:helper.is_hidden() abort
  return self.trea.hidden is# 1
endfunction


" Async
function! s:helper.cancel() abort
  call trea#internal#core#cancel(self.trea)
  return s:Promise.resolve()
endfunction

function! s:helper.redraw() abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#renderer#render(
        \   self.trea.nodes,
        \   self.trea.marks,
        \ )
        \})
        \.then({ v -> trea#lib#buffer#replace(self.bufnr, v) })
endfunction

function! s:helper.focus_node(key, ...) abort
  let options = extend({
        \ 'offset': 0,
        \ 'previous': v:null
        \}, a:0 ? a:1 : {})
  let index = trea#internal#node#index(a:key, self.trea.nodes)
  if index is# -1
    if !empty(a:key)
      return self.focus_node(a:key[:-2], options)
    endif
    return s:Promise.reject(printf('failed to find a node %s', a:key))
  endif
  let cursor = self.get_cursor()
  if options.previous is# v:null || options.previous == cursor
    call self.set_cursor([index + 1 + options.offset, cursor[1]])
  endif
  return s:Promise.resolve()
endfunction

function! s:helper.reload_node(key) abort
  let node = trea#internal#node#find(a:key, self.trea.nodes)
  if empty(node)
    return s:Promise.reject(printf('failed to find a node %s', a:key))
  endif
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#reload(
        \   node,
        \   self.trea.nodes,
        \   self.trea.provider,
        \   self.trea.comparator,
        \   self.trea.source.token,
        \ )
        \})
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.expand_node(key) abort
  let node = trea#internal#node#find(a:key, self.trea.nodes)
  if empty(node)
    return s:Promise.reject(printf('failed to find a node %s', a:key))
  endif
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#expand(
        \   node,
        \   self.trea.nodes,
        \   self.trea.provider,
        \   self.trea.comparator,
        \   self.trea.source.token,
        \ )
        \})
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.collapse_node(key) abort
  let node = trea#internal#node#find(a:key, self.trea.nodes)
  if empty(node)
    return s:Promise.reject(printf('failed to find a node %s', a:key))
  endif
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#collapse(
        \   node,
        \   self.trea.nodes,
        \   self.trea.provider,
        \   self.trea.comparator,
        \   self.trea.source.token,
        \ )
        \})
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.reveal_node(key) abort
  return s:Promise.resolve()
        \.then({ -> trea#internal#node#reveal(
        \   a:key,
        \   self.trea.nodes,
        \   self.trea.provider,
        \   self.trea.comparator,
        \   self.trea.source.token,
        \ )
        \})
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.set_mark(node) abort
  let key = a:node.__key
  if index(self.trea.marks, key) isnot# -1
    return s:Promise.resolve()
  endif
  call add(self.trea.marks, key)
  return s:Promise.resolve(self.trea.marks)
        \.then({ v -> trea#internal#core#update_marks(self.trea, v) })
endfunction

function! s:helper.unset_mark(node) abort
  let key = a:node.__key
  let index = index(self.trea.marks, key)
  if index is# -1
    return s:Promise.resolve()
  endif
  call remove(self.trea.marks, index)
  return s:Promise.resolve(self.trea.marks)
        \.then({ v -> trea#internal#core#update_marks(self.trea, v) })
endfunction

function! s:helper.set_hidden() abort
  if self.trea.hidden
    return s:Promise.resolve()
  endif
  let self.trea.hidden = 1
  return s:Promise.resolve(self.trea.nodes)
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.unset_hidden() abort
  if !self.trea.hidden
    return s:Promise.resolve()
  endif
  let self.trea.hidden = 0
  return s:Promise.resolve(self.trea.nodes)
        \.then({ -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.filter(pattern) abort
  if self.trea.pattern ==# a:pattern
    return s:Promise.resolve()
  endif
  let self.trea.pattern = a:pattern
  return s:Promise.resolve(self.trea.nodes)
        \.then({ v -> trea#internal#core#update_nodes(self.trea, v) })
endfunction

function! s:helper.enter_tree(node) abort
  if a:node.status is# self.STATUS_NONE
    return s:Promise.reject()
  endif
  return s:Promise.resolve(a:node)
        \.then({ n -> s:enter(self.trea, n) })
endfunction

function! s:helper.leave_tree() abort
  return s:Promise.resolve(self.trea.root)
        \.then({ root -> trea#internal#node#parent(
        \   root,
        \   self.trea.provider,
        \   self.trea.source.token,
        \ )
        \})
        \.then({ n -> s:enter(self.trea, n) })
endfunction


" Private
function! s:enter(trea, node) abort
  if !has_key(a:node, 'bufname')
    return s:Promise.reject('the node does not have bufname attribute')
  endif
  let url = trea#lib#url#parse(bufname('%'))
  let url.path = a:node.bufname
  execute printf('edit %s', fnameescape(url.to_string()))
endfunction
