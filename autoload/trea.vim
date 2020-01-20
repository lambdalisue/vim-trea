function! trea#uri(bufname) abort
  return matchstr(a:bufname, 'trea://\zs.*')
endfunction

function! trea#proto(uri) abort
  return matchstr(a:uri, '^.\{-}\ze://')
endfunction
