let s:Config = vital#trea#import('Config')
let s:Later = vital#trea#import('Async.Later')
let s:Lambda = vital#trea#import('Lambda')
let s:Chunker = vital#trea#import('Data.List.Chunker')
let s:Promise = vital#trea#import('Async.Promise')

function! trea#lib#writer#write(bufnr, content) abort
  let r = getbufvar(a:bufnr, 'trea_writer_resolver', v:null)
  if r isnot# v:null
    return r.then({ -> trea#lib#writer#write(a:bufnr, a:content) })
  endif
  let s = len(a:content)
  let t = g:trea#lib#writer#threshold
  let c = s:Chunker.new(t, a:content)
  let p = s:Promise.new({ resolve -> s:write(a:bufnr, c, 0, resolve)})
        \.finally({ -> setbufvar(a:bufnr, 'trea_writer_resolver', v:null) })
  call setbufvar(a:bufnr, 'trea_writer_resolver', p)
  return p
endfunction

function! trea#lib#writer#replace(bufnr, content) abort
  let r = getbufvar(a:bufnr, 'trea_writer_resolver', v:null)
  if r isnot# v:null
    return r.then({ -> trea#lib#writer#replace(a:bufnr, a:content) })
  endif
  let winid = bufwinid(a:bufnr)
  let s = len(a:content)
  let t = g:trea#lib#writer#threshold
  let c = s:Chunker.new(t, a:content)
  let p = s:Promise.new({ resolve -> s:write(a:bufnr, c, 0, resolve)})
        \.then({ -> s:deletebufline(a:bufnr, len(a:content) + 1, '$') })
        \.finally({ -> setbufvar(a:bufnr, 'trea_writer_resolver', v:null) })
  call setbufvar(a:bufnr, 'trea_writer_resolver', p)
  return p
endfunction

function! s:write(bufnr, chunker, offset, resolve) abort
  let chunk = a:chunker.next()
  let chunk_size = len(chunk)
  if chunk_size is# 0
    call a:resolve()
    return
  endif
  call s:setbufline(a:bufnr, 1 + a:offset, chunk)
  call s:Later.call({ ->
        \ s:write(a:bufnr, a:chunker, a:offset + chunk_size, a:resolve)
        \})
endfunction

function! s:setbufline(bufnr, lnum, text) abort
  let modified_saved = getbufvar(a:bufnr, '&modified')
  let modifiable_saved = getbufvar(a:bufnr, '&modifiable')
  try
    call setbufvar(a:bufnr, '&modifiable', 1)
    call setbufline(a:bufnr, a:lnum, a:text)
  finally
    call setbufvar(a:bufnr, '&modifiable', modifiable_saved)
    call setbufvar(a:bufnr, '&modified', modified_saved)
  endtry
endfunction

function! s:deletebufline(bufnr, first, last) abort
  let modified_saved = getbufvar(a:bufnr, '&modified')
  let modifiable_saved = getbufvar(a:bufnr, '&modifiable')
  try
    call setbufvar(a:bufnr, '&modifiable', 1)
    call deletebufline(a:bufnr, a:first, a:last)
  finally
    call setbufvar(a:bufnr, '&modifiable', modifiable_saved)
    call setbufvar(a:bufnr, '&modified', modified_saved)
  endtry
endfunction

call s:Config.config(expand('<sfile>:p'), {
      \ 'threshold': 1000,
      \})
