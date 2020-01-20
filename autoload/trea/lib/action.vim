let s:Lambda = vital#trea#import('Lambda')
let s:varname = 'trea_action'

function! trea#lib#action#init(prefix) abort
  let b:{s:varname} = {
        \ 'prefix': a:prefix,
        \ 'previous': '',
        \}
  execute printf(
       \ 'nnoremap <buffer><silent> <Plug>(%schoice) :<C-u>call %s()<CR>',
       \ a:prefix,
       \ get(function('s:map_choice'), 'name'),
       \)
  execute printf(
       \ 'nnoremap <buffer><silent> <Plug>(%srepeat) :<C-u>call %s()<CR>',
       \ a:prefix,
       \ get(function('s:map_repeat'), 'name'),
       \)
  execute printf('nmap <buffer> a <Plug>(%schoice)', a:prefix)
  execute printf('nmap <buffer> . <Plug>(%srepeat)', a:prefix)
endfunction

function! trea#lib#action#call(name) abort
  let action = get(b:, s:varname, v:null)
  if action is# v:null
    throw printf('no variable %s found in the buffer', s:varname)
  endif
  let actions = s:build_actions(action.prefix)
  let expr = get(actions, a:name, v:null)
  if expr is# v:null
    throw printf('no action %s found in the buffer', a:name)
  endif
  execute printf("normal \<Plug>(%s)", expr)
  let action.previous = a:name
endfunction

function! s:map_choice() abort
  let action = get(b:, s:varname, v:null)
  if action is# v:null
    throw printf('no variable %s found in the buffer', s:varname)
  endif
  call inputsave()
  try
    let n = get(function('s:complete_choice'), 'name')
    let r = input("action: ", '', printf('customlist,%s', n))
    let names = sort(keys(s:build_actions(action.prefix)))
    let name = get(filter(names, { -> v:val =~# '^' . r }), 0)
    if empty(name)
      return
    endif
    call trea#lib#action#call(name)
  finally
    call inputrestore()
  endtry
endfunction

function! s:map_repeat() abort
  let action = get(b:, s:varname, v:null)
  if action is# v:null
    throw printf('no variable %s found in the buffer', s:varname)
  endif
  if empty(action.previous)
    return
  endif
  call trea#lib#action#call(action.previous)
endfunction

function! s:build_actions(prefix) abort
  let ms = split(execute(printf('nmap <Plug>(%s', a:prefix)), '\n')
  call map(ms, { _, v -> split(v)[1] })
  call map(ms, { _, v -> matchstr(v, '^<Plug>(\zs.*\ze)$') })
  call filter(ms, { _, v -> !empty(v) })
  let actions = {}
  for expr in ms
    let name = expr[len(a:prefix):]
    let actions[name] = expr
  endfor
  return actions
endfunction

function! s:complete_choice(arglead, cmdline, cursorpos) abort
  let action = get(b:, s:varname, v:null)
  if action is# v:null
    throw printf('no variable %s found in the buffer', s:varname)
  endif
  let names = sort(keys(s:build_actions(action.prefix)))
  if empty(a:arglead)
    call filter(names, { -> v:val !~# ':' })
  endif
  return filter(names, { -> v:val =~# '^' . a:arglead })
endfunction
