let s:WindowCursor = vital#trea#import('Vim.Window.Cursor')

function! trea#lib#buffer#replace(bufnr, content) abort
  let winid = bufwinid(a:bufnr)
  let cursor = s:WindowCursor.get_cursor(winid)
  let modified_saved = getbufvar(a:bufnr, '&modified')
  let modifiable_saved = getbufvar(a:bufnr, '&modifiable')
  call setbufvar(a:bufnr, '&modifiable', 1)
  call deletebufline(a:bufnr, 1, '$')
  call setbufline(a:bufnr, 1, a:content)
  call setbufvar(a:bufnr, '&modifiable', modifiable_saved)
  call setbufvar(a:bufnr, '&modified', modified_saved)
  call s:WindowCursor.set_cursor(winid, cursor)
endfunction
