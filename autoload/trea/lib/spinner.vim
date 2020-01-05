let s:Lambda = vital#trea#import('Lambda')

" NOTE:
" Any characters of 's:frames' in a target buffer will be replaced
" so use characters which are seldome used.
let s:frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
let s:frame_count = len(s:frames)
let s:frame_pattern = printf("[%s]", join(s:frames, ''))

function! trea#lib#spinner#start(...) abort
  let options = extend({
        \ 'bufnr': bufnr('%'),
        \ 'interval': 50,
        \}, a:0 ? a:1 : {})
  let spinner = getbufvar(options.bufnr, 'trea_spinner', {
        \ 'processing': 0,
        \ 'timer': v:null,
        \ 'index': 0,
        \ 'ref_count': 0,
        \})
  call s:register(spinner, options)
endfunction

function! trea#lib#spinner#stop(...) abort
  let options = extend({
        \ 'bufnr': bufnr('%'),
        \}, a:0 ? a:1 : {})
  let spinner = getbufvar(options.bufnr, 'trea_spinner', {
        \ 'timer': v:null,
        \ 'index': 0,
        \ 'ref_count': 1,
        \})
  call s:unregister(spinner, options)
endfunction

function! s:register(spinner, options) abort
  let a:spinner.ref_count += 1
  if a:spinner.timer is# v:null
    let a:spinner.timer = timer_start(
          \ a:options.interval,
          \ { -> s:update_buffer(a:options.bufnr, a:spinner) },
          \ { 'repeat': -1 },
          \)
  endif
  call setbufvar(a:options.bufnr, 'trea_spinner', a:spinner)
endfunction

function! s:unregister(spinner, options) abort
  let a:spinner.ref_count -= 1
  if a:spinner.ref_count <= 0
    if a:spinner.timer isnot# v:null
      call timer_stop(a:spinner.timer)
      let a:spinner.timer = v:null
    endif
    let a:spinner.ref_count = 0
    let a:spinner.index = 0
  endif
endfunction

function! s:update_buffer(bufnr, spinner) abort
  if bufwinnr(a:bufnr) is# -1 || a:spinner.processing
    " The buffer is not shown in window so skip
    return
  endif
  let frame = s:frames[a:spinner.index]
  let content = getbufline(a:bufnr, 1, '$')
  let a:spinner.index = (a:spinner.index + 1) % s:frame_count
  let a:spinner.processing = 1
  call trea#lib#gradual#map(content, { v -> substitute(v, s:frame_pattern, frame, 'g') })
        \.then({ v -> trea#lib#writer#replace(a:bufnr, v) })
        \.finally({ -> s:Lambda.let(a:spinner, 'processing', 0) })
  " call trea#lib#gradual#map(content, { v -> substitute(v, s:frame_pattern, frame, 'g') })
  "      \.then({ content -> s:Lambda.void(
  "      \   trea#lib#writer#setbufline(a:bufnr, 1, content),
  "      \   trea#lib#writer#deletebufline(a:bufnr, len(content) + 1, '$'),
  "      \ )})
  "      \.finally({ -> s:Lambda.let(a:spinner, 'processing', 0) })
endfunction


let g:trea#lib#spinner#PLACEHOLDER = s:frames[0]
lockvar g:trea#lib#spinner#PLACEHOLDER
