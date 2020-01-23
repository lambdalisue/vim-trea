let s:Config = vital#trea#import('Config')
let s:Promise = vital#trea#import('Async.Promise')
let s:Prompt = vital#trea#import('Prompt')
let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

function! trea#internal#mapping#init() abort
  nnoremap <buffer><silent> <Plug>(trea-echo)          :<C-u>call <SID>call('echo')<CR>
  nnoremap <buffer><silent> <Plug>(trea-cancel)        :<C-u>call <SID>call('cancel')<CR>
  nnoremap <buffer><silent> <Plug>(trea-redraw)        :<C-u>call <SID>call('redraw')<CR>
  nnoremap <buffer><silent> <Plug>(trea-reload)        :<C-u>call <SID>call('reload')<CR>
  nnoremap <buffer><silent> <Plug>(trea-expand)        :<C-u>call <SID>call('expand')<CR>
  nnoremap <buffer><silent> <Plug>(trea-collapse)      :<C-u>call <SID>call('collapse')<CR>
  nnoremap <buffer><silent> <Plug>(trea-reveal)        :<C-u>call <SID>call('reveal')<CR>
  nnoremap <buffer><silent> <Plug>(trea-enter)         :<C-u>call <SID>call('enter')<CR>
  nnoremap <buffer><silent> <Plug>(trea-leave)         :<C-u>call <SID>call('leave')<CR>
  nnoremap <buffer><silent> <Plug>(trea-set-mark)      :<C-u>call <SID>call('set_mark')<CR>
  nnoremap <buffer><silent> <Plug>(trea-unset-mark)    :<C-u>call <SID>call('unset_mark')<CR>
  nnoremap <buffer><silent> <Plug>(trea-toggle-mark)   :<C-u>call <SID>call('toggle_mark')<CR>
  nnoremap <buffer><silent> <Plug>(trea-set-hidden)    :<C-u>call <SID>call('set_hidden')<CR>
  nnoremap <buffer><silent> <Plug>(trea-unset-hidden)  :<C-u>call <SID>call('unset_hidden')<CR>
  nnoremap <buffer><silent> <Plug>(trea-toggle-hidden) :<C-u>call <SID>call('toggle_hidden')<CR>
  nnoremap <buffer><silent> <Plug>(trea-filter)        :<C-u>call <SID>call('filter')<CR>
  vnoremap <buffer><silent> <Plug>(trea-set-mark)      :call <SID>call('set_mark')<CR>
  vnoremap <buffer><silent> <Plug>(trea-unset-mark)    :call <SID>call('unset_mark')<CR>
  vnoremap <buffer><silent> <Plug>(trea-toggle-mark)   :call <SID>call('toggle_mark')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:select)   :<C-u>call <SID>call('open', 'select')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:edit)     :<C-u>call <SID>call('open', 'edit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:split)    :<C-u>call <SID>call('open', 'split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:vsplit)   :<C-u>call <SID>call('open', 'vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:tabedit)  :<C-u>call <SID>call('open', 'tabedit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:above)    :<C-u>call <SID>call('open', 'leftabove split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:left)     :<C-u>call <SID>call('open', 'leftabove vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:below)    :<C-u>call <SID>call('open', 'rightbelow split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:right)    :<C-u>call <SID>call('open', 'rightbelow vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:top)      :<C-u>call <SID>call('open', 'topleft split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:leftest)  :<C-u>call <SID>call('open', 'topleft vsplit')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:bottom)   :<C-u>call <SID>call('open', 'botright split')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:rightest) :<C-u>call <SID>call('open', 'botright vsplit')<CR>

  nmap <buffer><silent><expr> <Plug>(trea-enter-or-open) <SID>is_branch()
        \ ? "\<Plug>(trea-enter)"
        \ : "\<Plug>(trea-open)"
  nmap <buffer><silent><expr> <Plug>(trea-expand-or-open) <SID>is_branch()
        \ ? "\<Plug>(trea-expand)"
        \ : "\<Plug>(trea-open)"
  nmap <buffer><silent> <Plug>(trea-open) <Plug>(trea-open:edit)

  if !g:trea#internal#mapping#disable_default_mappings
    nmap <buffer><nowait> <C-c> <Plug>(trea-cancel)
    nmap <buffer><nowait> <C-l> <Plug>(trea-redraw)
    nmap <buffer><nowait> <F5> <Plug>(trea-reload)
    nmap <buffer><nowait> <Return> <Plug>(trea-enter-or-open)
    nmap <buffer><nowait> <Backspace> <Plug>(trea-leave)
    nmap <buffer><nowait> l <Plug>(trea-expand-or-open)
    nmap <buffer><nowait> h <Plug>(trea-collapse)
    nmap <buffer><nowait> i <Plug>(trea-reveal)
    nmap <buffer><nowait> - <Plug>(trea-toggle-mark)
    nmap <buffer><nowait> <C-j> <Plug>(trea-toggle-mark)j
    nmap <buffer><nowait> <C-k> k<Plug>(trea-toggle-mark)
    vmap <buffer><nowait> - <Plug>(trea-toggle-mark)
    nmap <buffer><nowait> ! <Plug>(trea-toggle-hidden)
    nmap <buffer><nowait> f <Plug>(trea-filter)
  endif
endfunction

function! s:is_branch() abort
  let helper = trea#helper#new()
  let node = helper.get_cursor_node()
  if node is# v:null
    throw 'no node found on a cursor line'
  endif
  return node.status isnot# 0
endfunction

function! s:call(name, ...) abort
  let Fn = funcref(printf('s:map_%s', a:name))
  let r = call('trea#helper#call', [Fn] + a:000)
  if s:Promise.is_promise(r)
    call r.catch({ e -> trea#lib#message#error(e) })
  endif
endfunction

function! s:map_echo(helper) abort
  let node = a:helper.get_cursor_node()
  let text = ""
  let text .= printf("label:        %s\n", node.label)
  let text .= printf("hidden:       %s\n", node.hidden)
  let text .= printf("__key:        %s\n", node.__key)
  let text .= printf("__owner:      %s\n", node.__owner is# v:null ? '' : node.__owner.label)
  let text .= printf("__processing: %s\n", node.__processing)
  redraw | echo text
endfunction

function! s:map_cancel(helper) abort
  return a:helper.cancel()
endfunction

function! s:map_redraw(helper) abort
  return a:helper.redraw()
endfunction

function! s:map_reload(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return a:helper.reload_node(node.__key)
        \.then({ -> a:helper.redraw() })
endfunction

function! s:map_expand(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  let cursor = a:helper.get_cursor()
  return a:helper.expand_node(node.__key)
        \.then({ -> a:helper.redraw() })
        \.then({ -> a:helper.focus_node(
        \   node.__key,
        \   { 'prefioux': cursor, 'offset': 1 },
        \ )
        \})
endfunction

function! s:map_collapse(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  let cursor = a:helper.get_cursor()
  return a:helper.collapse_node(node.__key)
        \.then({ -> a:helper.redraw() })
        \.then({ -> a:helper.focus_node(
        \   node.__key,
        \   { 'prefioux': cursor },
        \ )
        \})
endfunction

function! s:map_reveal(helper) abort
  let node = a:helper.get_cursor_node()
  let path = node is# v:null
        \ ? ''
        \ : join(node.__key, '/') . '/'
  let path = s:Prompt.ask("Please input a path to reveal: ", path)
  if empty(path)
    return s:Promise.reject("Cancelled")
  endif
  let root = a:helper.get_root_node()
  let key = split(path, '/')
  let cursor = a:helper.get_cursor()
  return a:helper.reveal_node(key)
        \.then({ -> a:helper.redraw() })
        \.then({ -> a:helper.focus_node(
        \   key,
        \   { 'prefioux': cursor },
        \ )
        \})
endfunction

function! s:map_set_mark(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return a:helper.set_mark(node)
endfunction

function! s:map_unset_mark(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return a:helper.unset_mark(node)
endfunction

function! s:map_toggle_mark(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  if a:helper.is_marked(node)
    return a:helper.unset_mark(node)
  else
    return a:helper.set_mark(node)
  endif
endfunction

function! s:map_set_hidden(helper) abort
  return a:helper.set_hidden()
endfunction

function! s:map_unset_hidden(helper) abort
  return a:helper.unset_hidden()
endfunction

function! s:map_toggle_hidden(helper) abort
  if a:helper.is_hidden()
    return a:helper.unset_hidden()
  else
    return a:helper.set_hidden()
  endif
endfunction

function! s:map_filter(helper) abort
  let input = s:Prompt.ask("Please input a pattern: ", a:helper.trea.pattern)
  return s:Promise.resolve()
        \.then({ -> a:helper.filter(input) })
        \.then({ -> a:helper.redraw() })
endfunction

function! s:map_open(helper, opener) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return trea#lib#buffer#open(node.bufname, {
        \ 'opener': a:opener,
        \})
endfunction

function! s:map_enter(helper) abort
  let node = a:helper.get_cursor_node()
  if node is# v:null
    return s:Promise.reject("no node found on a cursor line")
  endif
  return a:helper.enter_tree(node)
endfunction

function! s:map_leave(helper) abort
  return a:helper.leave_tree()
endfunction

call s:Config.config(expand('<sfile>:p'), {
      \ 'disable_default_mappings': 0,
      \})
