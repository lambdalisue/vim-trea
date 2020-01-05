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
  if bufwinnr(a:bufnr) is# -1
    " The buffer is not shown in window so skip
    return
  endif
  let v = s:frames[a:spinner.index]
  let content = getbufline(a:bufnr, 1, '$')
  call map(content, { -> substitute(v:val, s:frame_pattern, v, 'g') })
  call trea#lib#buffer#replace(a:bufnr, content)
  let a:spinner.index = (a:spinner.index + 1) % s:frame_count
endfunction


let g:trea#lib#spinner#PLACEHOLDER = s:frames[0]
lockvar g:trea#lib#spinner#PLACEHOLDER
