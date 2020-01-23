let s:Promise = vital#trea#import('Async.Promise')

function! trea#viewer#init() abort
  if exists('b:trea')
    return
  endif
  doautocmd <nomodeline> User TreaInitPre
  let url = trea#lib#url#parse(bufname('%'))
  let scheme = trea#lib#url#parse(url.path).scheme
  let provider = trea#scheme#{scheme}#provider#new()
  doautocmd <nomodeline> User TreaInit

  setlocal buftype=nofile bufhidden=unload
  setlocal noswapfile nobuflisted nomodifiable
  setlocal signcolumn=yes:1
  setlocal filetype=trea

  augroup trea_core_internal
    autocmd! * <buffer>
    autocmd BufEnter <buffer> setlocal nobuflisted
    autocmd BufReadCmd <buffer> nested call s:BufReadCmd()
    autocmd ColorScheme <buffer> call s:ColorScheme()
    autocmd CursorMoved,CursorMovedI <buffer> let b:trea_cursor = getcurpos()
  augroup END

  call trea#internal#renderer#highlight()
  call trea#internal#renderer#syntax()
  call trea#internal#mapping#init()
  call trea#scheme#{scheme}#mapping#init()
  call trea#lib#action#init('trea-')
  doautocmd <nomodeline> User TreaReady

  let bufnr = bufnr('%')
  return trea#internal#core#new(url.path, provider)
        \.then({ trea -> setbufvar(bufnr, 'trea', trea) })
        \.then({ -> trea#internal#spinner#start() })
        \.then({ -> s:init(trea#helper#new()) })
endfunction

function! s:init(helper) abort
  let root = a:helper.get_root_node()
  return s:Promise.resolve()
        \.then({ -> a:helper.expand_node(root.__key) })
        \.then({ -> a:helper.redraw() })
endfunction

function! s:BufReadCmd() abort
  let cursor = get(b:, 'trea_cursor', getcurpos())
  let helper = trea#helper#new()
  let root = helper.get_root_node()
  call trea#internal#renderer#syntax()
  call s:Promise.resolve()
        \.then({ -> helper.redraw() })
        \.then({ -> helper.set_cursor(cursor[1:2]) })
        \.then({ -> helper.reload_node(root.__key) })
        \.then({ -> helper.redraw() })
        \.catch({ e -> trea#lib#message#error(e) })
endfunction

function! s:ColorScheme() abort
  call trea#internal#renderer#highlight()
endfunction


augroup trea_viewer_internal
  autocmd! *
  autocmd User TreaInitPre :
  autocmd User TreaInit :
  autocmd User TreaReady :
augroup END
