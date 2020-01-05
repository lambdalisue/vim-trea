let s:Config = vital#trea#import('Config')
let s:Lambda = vital#trea#import('Lambda')
let s:Spinner = vital#trea#import('App.Spinner')

function! trea#lib#spinner#start(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let spinner = getbufvar(bufnr, 'trea_spinner', {
        \ 'index': 0,
        \ 'count': 0,
        \ 'spinner': s:Spinner.new(get(s:Spinner, g:trea#lib#spinner#name)),
        \})
  call s:register(bufnr, spinner)
  call setbufvar(bufnr, 'trea_spinner', spinner)
endfunction

function! trea#lib#spinner#stop(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  let spinner = getbufvar(bufnr, 'trea_spinner', {
        \ 'timer': v:null,
        \ 'index': 0,
        \ 'ref_count': 1,
        \})
  call s:unregister(bufnr, spinner)
endfunction

function! s:register(bufnr, spinner) abort
  let a:spinner.count += 1
  if !has_key(a:spinner, 'timer')
    let a:spinner.statusline = getbufvar(a:bufnr, '&statusline')
    let a:spinner.timer = timer_start(
          \ g:trea#lib#spinner#interval,
          \ { -> s:update_buffer(a:bufnr, a:spinner) },
          \ { 'repeat': -1 },
          \)
  endif
endfunction

function! s:unregister(bufnr, spinner) abort
  let a:spinner.count -= 1
  if a:spinner.count <= 0
    if a:spinner.timer isnot# v:null
      call timer_stop(a:spinner.timer)
      call setbufvar(a:bufnr, '&statusline', a:spinner.statusline)
      unlet a:spinner.timer
      unlet a:spinner.statusline
    endif
    let a:spinner.count = 0
    let a:spinner.index = 0
  endif
endfunction

function! s:update_buffer(bufnr, spinner) abort
  if bufwinnr(a:bufnr) is# -1
    " The buffer is not shown in window so skip
    return
  endif
  let m = printf(g:trea#lib#spinner#format, a:spinner.spinner.next())
  call setbufvar(a:bufnr, '&statusline', m)
  redrawstatus
endfunction


call s:Config.config(expand('<sfile>:p'), {
      \ 'name': 'dots',
      \ 'format': 'Loading ... %s',
      \ 'interval': 50,
      \})
