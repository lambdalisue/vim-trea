if exists('g:trea_file_loaded')
  finish
endif
let g:trea_file_loaded = 1

function! s:TreaInit() abort
  if trea#proto(trea#uri(expand('%'))) ==# 'file'
    call trea#proto#file#mapping#init()
  endif
endfunction

augroup trea_plugin
  autocmd! *
  autocmd User TreaInit call s:TreaInit()
augroup END
