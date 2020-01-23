function! trea#lib#url#parse(url) abort
  let u = s:unescape(matchstr(a:url, '^.\{-}\ze\%(?.\{-}\)\?\%(#.*\)\?$'))
  let q = s:parse_qs(matchstr(a:url, '\%(?\zs.\{-}\ze\)\%(#.*\)\?$'))
  let f = matchstr(a:url, '\%(#\zs.*\ze\)$')
  let m = matchlist(u, '^\([^:]\+\):\%(//\([^/]*\)\)\?\(.*\)$')
  let a = a:url =~# '^[^:]\+://'
  if empty(m)
    let url = {
          \ 'scheme': '',
          \ 'authority': v:null,
          \ 'path': u,
          \ 'query': q,
          \ 'fragment': f,
          \}
  else
    let url = {
          \ 'scheme': m[1],
          \ 'authority': empty(m[2]) && !a ? v:null : m[2],
          \ 'path': m[3],
          \ 'query': q,
          \ 'fragment': f,
          \}
  endif
  let url.to_string = funcref('s:to_string')
  return url
endfunction

function! s:to_string() abort dict
  let url = printf("%s:", self.scheme)
  if self.authority isnot# v:null
    let url .= printf("//%s", self.authority)
  endif
  let url .= self.path
  if !empty(self.query)
    let url .= printf("?%s", s:format_query(self.query))
  endif
  if !empty(self.fragment)
    let url .= printf("#%s", self.fragment)
  endif
  return url
endfunction

function! s:parse_qs(qs) abort
  let obj = {}
  let terms = split(a:qs, '&\%(\w\+;\)\@!')
  call map(terms, { _, v -> (split(v, '=', 1) + [v:true])[:1] })
  call map(terms, { _, v -> extend(obj, {s:unescape(v[0]): s:unescape(v[1])})})
  return obj
endfunction

function! s:format_query(query) abort
  let terms = map(
        \ items(a:query),
        \ { _, v -> printf("%s=%s", s:escape(v[0]), s:escape(v[1])) },
        \)
  return join(terms, '&')
endfunction

function! s:escape(text) abort
  let chars = '% ?#'
  let text = a:text
  for char in split(chars, '\zs')
    let text = substitute(text, char, '%' . char2nr(char), 'g')
  endfor
  return text
endfunction

function! s:unescape(text) abort
  let text = a:text
  let hex = matchstr(text, '%\zs[0-9a-fA-F]\{2}')
  while !empty(hex)
    let text = substitute(text, '%' . hex, nr2char(str2nr(hex, 16)), 'ig')
    let hex = matchstr(text, '%\zs[0-9a-fA-F]\{2}')
  endwhile
  return text
endfunction
