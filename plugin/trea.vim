if exists('g:trea_loaded')
  finish
endif
let g:trea_loaded = 1

function! s:trea_test() abort
  vertical new trea://test
  " let provider = trea#provider#debug#new()
  let provider = trea#provider#file#new()
  call trea#viewer#init("file:///", provider)
endfunction

command! -nargs=* -complete=dir TreaTest call s:trea_test()
