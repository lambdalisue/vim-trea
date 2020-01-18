if exists('g:trea_loaded')
  finish
endif
let g:trea_loaded = 1

function! s:BufReadCmd() abort
  if exists('b:trea')
    return
  endif
  let uri = matchstr(expand('<afile>:p'), 'trea://\zs.*')
  let proto = matchstr(uri, '^.\{-}\ze://')
  call trea#core#init(uri, trea#proto#{proto}#provider#new())
endfunction

augroup trea_entry
  autocmd! *
  autocmd BufReadCmd trea://* call s:BufReadCmd()
augroup END

function! s:trea_test() abort
  vertical new trea://test
  let provider = trea#proto#debug#provider#new()
  let provider = trea#proto#file#provider#new()
  call trea#core#init("file:///", provider)
endfunction

command! -nargs=* -complete=dir TreaTest call s:trea_test()
