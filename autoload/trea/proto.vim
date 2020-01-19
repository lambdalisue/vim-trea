function! trea#proto#get(...) abort
  let bufname = a:0 ? a:1 : bufname('%')
  let uri = matchstr(bufname, 'trea://\zs.*')
  let proto = matchstr(uri, '^.\{-}\ze://')
  return proto
endfunction

function! trea#proto#provider_new(...) abort
  let proto = call('trea#proto#get', a:000)
  return trea#proto#{proto}#provider#new()
endfunction

function! trea#proto#mapping_init(...) abort
  let proto = call('trea#proto#get', a:000)
  try
    call trea#proto#{proto}#mapping#init()
    return 1
  catch /^Vim\%((\a\+)\)\=:E117: [^:]\+: trea#proto#[^#]\+mapping#init/
  endtry
endfunction
