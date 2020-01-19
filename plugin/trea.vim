if exists('g:trea_loaded')
  finish
endif
let g:trea_loaded = 1

function! s:BufReadCmd() abort
  if exists('b:trea')
    return
  endif
  let provider = trea#proto#provider_new(expand('<afile>'))
  call trea#core#init(uri, provider)
endfunction

augroup trea_entry
  autocmd! *
  autocmd BufReadCmd trea://* call s:BufReadCmd()
augroup END

function! s:trea_test() abort
  vertical new trea://file:///Users/alisue/
endfunction

command! -nargs=* -complete=dir TreaTest call s:trea_test()
