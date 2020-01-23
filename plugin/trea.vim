if exists('g:trea_loaded')
  finish
endif
let g:trea_loaded = 1

function! s:BufReadCmd() abort
  if exists('b:trea')
    return
  endif
  let bufname = bufname('%')
  if bufname !~# '#[a-f0-9]\+$'
    let bufname = printf("%s#%s", bufname, sha256(localtime())[:7])
    execute printf(
          \ "silent keepalt file %s",
          \ fnameescape(bufname),
          \)
  endif
  call trea#viewer#init()
        \.catch({ e -> trea#lib#message#error(e) })
endfunction

augroup trea_plugin
  autocmd! *
  autocmd BufReadCmd trea:*/* call s:BufReadCmd()
augroup END
