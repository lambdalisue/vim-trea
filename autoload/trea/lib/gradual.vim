let s:Config = vital#trea#import('Config')
let s:Later = vital#trea#import('Async.Later')
let s:Lambda = vital#trea#import('Lambda')
let s:Promise = vital#trea#import('Async.Promise')
let s:Chunker = vital#trea#import('Data.List.Chunker')

function! trea#lib#gradual#map(list, fn) abort
  let s = len(a:list)
  let t = g:trea#lib#gradual#threshold
  let c = s:Chunker.new(t, a:list)
  return s:Promise.new({ resolve -> s:map(c, a:fn, [], 0, resolve)})
endfunction

function! trea#lib#gradual#filter(list, fn) abort
  let s = len(a:list)
  let t = g:trea#lib#gradual#threshold
  let c = s:Chunker.new(t, a:list)
  return s:Promise.new({ resolve -> s:filter(c, a:fn, [], 0, resolve)})
endfunction

function! trea#lib#gradual#reduce(list, fn, ...) abort
  let s = len(a:list)
  let t = g:trea#lib#gradual#threshold
  let a = a:0 ? a:1 : remove(a:list, 0)
  let c = s:Chunker.new(t, a:list)
  return s:Promise.new({ resolve -> s:reduce(c, a:fn, a, a:0 ? 1 : 0, resolve)})
endfunction

function! s:map(chunker, fn, result, offset, resolve) abort
  let chunk = a:chunker.next()
  let chunk_size = len(chunk)
  if chunk_size is# 0
    call a:resolve(a:result)
    return
  endif
  call extend(a:result, map(chunk, { k, v -> a:fn(v, a:offset + k) }))
  call s:Later.call({ ->
        \ s:map(a:chunker, a:fn, a:result, a:offset + chunk_size, a:resolve)
        \})
endfunction

function! s:filter(chunker, fn, result, offset, resolve) abort
  let chunk = a:chunker.next()
  let chunk_size = len(chunk)
  if chunk_size is# 0
    call a:resolve(a:result)
    return
  endif
  call extend(a:result, filter(chunk, { k, v -> a:fn(v, a:offset + k) }))
  call s:Later.call({ ->
        \ s:filter(a:chunker, a:fn, a:result, a:offset + chunk_size, a:resolve)
        \})
endfunction

function! s:reduce(chunker, fn, result, offset, resolve) abort
  let chunk = a:chunker.next()
  let chunk_size = len(chunk)
  if chunk_size is# 0
    call a:resolve(a:result)
    return
  endif
  let result = s:Lambda.reduce(
        \ chunk,
        \ { a, v, k -> a:fn(a, v, a:offset + k) },
        \ a:result,
        \)
  call s:Later.call({ ->
        \ s:reduce(a:chunker, a:fn, result, a:offset + chunk_size, a:resolve)
        \})
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'threshold': 1000,
      \})
