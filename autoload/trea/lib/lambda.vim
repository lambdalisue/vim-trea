function! trea#lib#lambda#map_f(fn) abort
  return { list -> trea#lib#gradual#map(list, a:fn) }
endfunction

function! trea#lib#lambda#filter_f(fn) abort
  return { list -> trea#lib#gradual#filter(list, a:fn) }
endfunction

function! trea#lib#lambda#reduce_f(fn, ...) abort
  let args = a:000
  return { list -> call('trea#lib#gradual#reduce', [list, a:fn] + args) }
endfunction
