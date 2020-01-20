let s:Config = vital#trea#import('Config')
let s:File = vital#trea#import('Async.File')

function! trea#proto#file#mapping#init() abort
  nnoremap <buffer><silent> <Plug>(trea-cd:cd)       :<C-u>call <SID>invoke('cd', 'cd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-cd:lcd)      :<C-u>call <SID>invoke('cd', 'lcd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-cd:tcd)      :<C-u>call <SID>invoke('cd', 'tcd')<CR>
  nnoremap <buffer><silent> <Plug>(trea-open:system) :<C-u>call <SID>invoke('open_system')<CR>

  nmap <buffer> <Plug>(trea-cd) <Plug>(trea-cd:tcd)

  if !g:trea#internal#mapping#disable_default_mappings
    nmap <buffer><nowait> x <Plug>(trea-open:system)
  endif
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

function! s:map_cd(trea, command) abort
  let path = a:trea.root._path
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

function! s:map_open_system(trea) abort
  let node = trea#core#get_cursor_node(a:trea)
  let path = node._path
  return s:File.open(path)
        \.then({ -> trea#lib#message#info(printf('%s is opened', path)) })
endfunction
