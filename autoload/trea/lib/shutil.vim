let s:File = vital#trea#import('Async.File')
let s:Promise = vital#trea#import('Async.Promise')
let s:Prompt = vital#trea#import('Prompt')
let s:CancellationToken = vital#trea#import('Async.CancellationToken')

function! trea#lib#shutil#open(path, ...) abort
  let token = a:0 ? a:1 : s:CancellationToken.none
  return s:File.open(a:path, {
        \ 'token': token,
        \})
endfunction

function! trea#lib#shutil#mkfile(path, ...) abort
  if filereadable(a:path) || isdirectory(a:path)
    return s:Promise.reject(printf("'%s' already exist", a:path))
  endif
  return s:Promise.resolve()
        \.then({ -> mkdir(fnamemodify(path, ':p:h'), 'p') })
        \.then({ -> writefile([], path) })
endfunction

function! trea#lib#shutil#mkdir(path, ...) abort
  if filereadable(a:path) || isdirectory(a:path)
    return s:Promise.reject(printf("'%s' already exist", a:path))
  endif
  return s:Promise.resolve()
        \.then({ -> mkdir(path, 'p') })
endfunction

function! trea#lib#shutil#copy(src, dst, ...) abort
  let token = a:0 ? a:1 : s:CancellationToken.none
  if filereadable(a:dst) || isdirectory(a:dst)
    let r = s:select_overwrite_method(a:dst)
    if empty(r)
      return s:Promise.reject('Cancelled')
    elseif r ==# 'r'
      let new_dst = s:Prompt.ask(
            \ printf("New name: %s -> ", a:src),
            \ a:dst,
            \ filereadable(a:src) ? 'file' : 'dir',
            \)
      if empty(new_dst)
        return s:Promise.reject('Cancelled')
      endif
      return trea#lib#shutil#copy(a:src, new_dst, token)
    endif
  endif
  return s:File.copy(a:src, a:dst, {
        \ 'token': token,
        \})
endfunction

function! trea#lib#shutil#move(src, dst, ...) abort
  let token = a:0 ? a:1 : s:CancellationToken.none
  if filereadable(a:dst) || isdirectory(a:dst)
    let r = s:select_overwrite_method(a:dst)
    if empty(r)
      return s:Promise.reject('Cancelled')
    elseif r ==# 'r'
      let new_dst = s:Prompt.ask(
            \ printf("New name: %s -> ", a:src),
            \ a:dst,
            \ filereadable(a:src) ? 'file' : 'dir',
            \)
      if empty(new_dst)
        return s:Promise.reject('Cancelled')
      endif
      return trea#lib#shutil#move(a:src, new_dst, token)
    endif
  endif
  return s:File.move(a:src, a:dst, {
        \ 'token': token,
        \})
endfunction

function! trea#lib#shutil#trash(path, ...) abort
  let token = a:0 ? a:1 : s:CancellationToken.none
  return s:File.trash(a:path, {
        \ 'token': token,
        \})
endfunction

function! trea#lib#shutil#remove(path, ...) abort
  return s:Promise.resolve()
        \.then({ -> delete(a:path, 'rf') })
endfunction

function! s:select_overwrite_method(path) abort
  let prompt = join([
        \ printf(
        \   'File/Directory "%s" already exists or not writable',
        \   a:path,
        \ ),
        \ 'Please select an overwrite method (esc to cancel)',
        \ 'f[orce]/r[ename]: ',
        \], "\n")
  return s:Prompt.select(prompt, 1, 1, '[fr]')
endfunction
