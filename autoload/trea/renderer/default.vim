let s:Config = vital#trea#import('Config')

let s:STATUS_COLLAPSED = g:trea#node#STATUS_COLLAPSED


function! trea#renderer#default#new() abort
  return {
        \ 'index': funcref('s:renderer_index'),
        \ 'render': funcref('s:renderer_render'),
        \ 'syntax': funcref('s:renderer_syntax'),
        \ 'highlight': funcref('s:renderer_highlight'),
        \}
endfunction

function! s:renderer_index(lnum) abort
  return a:lnum - 1
endfunction

function! s:renderer_render(nodes, marks) abort
  let options = {
        \ 'leading': g:trea#renderer#default#leading,
        \ 'root_symbol': g:trea#renderer#default#root_symbol,
        \ 'leaf_symbol': g:trea#renderer#default#leaf_symbol,
        \ 'expanded_symbol': g:trea#renderer#default#expanded_symbol,
        \ 'collapsed_symbol': g:trea#renderer#default#collapsed_symbol,
        \ 'marked_symbol': g:trea#renderer#default#marked_symbol,
        \ 'unmarked_symbol': g:trea#renderer#default#unmarked_symbol,
        \ 'processing_suffix': ' ' . g:trea#lib#spinner#PLACEHOLDER,
        \}
  let base = len(a:nodes[0].key)
  return map(copy(a:nodes), { -> s:render_node(v:val, a:marks, base, options) })
endfunction

function! s:renderer_syntax() abort
  syntax clear
  syntax match TreaRoot   /\%1l.*/
  syntax match TreaLeaf   /^\s*|  /
  syntax match TreaBranch /^\s*|[+-] .*/
  syntax match TreaMarked /^* .*/
endfunction

function! s:renderer_highlight() abort
  highlight default link TreaRoot   Directory
  highlight default link TreaLeaf   Directory
  highlight default link TreaBranch Directory
  highlight default link TreaMarked Title
endfunction

function! s:render_node(node, marks, base, options) abort
  let prefix = index(a:marks, a:node.key) is# -1
        \ ? a:options.unmarked_symbol
        \ : a:options.marked_symbol
  let suffix = a:node.__processing
        \ ? a:options.processing_suffix
        \ : ''
  let level = len(a:node.key) - a:base
  if level is# 0
    return prefix . a:options.root_symbol . a:node.text . suffix
  endif
  let leading = repeat(a:options.leading, level - 1)
  let symbol = a:node.branch
        \ ? a:node.__status is# s:STATUS_COLLAPSED
        \   ? a:options.collapsed_symbol
        \   : a:options.expanded_symbol
        \ : a:options.leaf_symbol
  return prefix . leading . symbol . a:node.text . suffix
endfunction

call s:Config.config(expand('<sfile>:p'), {
      \ 'leading': ' ',
      \ 'root_symbol': '',
      \ 'leaf_symbol': '|  ',
      \ 'expanded_symbol': '|- ',
      \ 'collapsed_symbol': '|+ ',
      \ 'marked_symbol': '* ',
      \ 'unmarked_symbol': '  ',
      \})
