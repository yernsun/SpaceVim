""
" @section checkers, layer-checkers
" @parentsection layers
" SpaceVim uses neomake as default syntax checker.

let s:SIG = SpaceVim#api#import('vim#signatures')
let s:STRING = SpaceVim#api#import('data#string')
function! SpaceVim#layers#checkers#plugins() abort
  let plugins = []

  if g:spacevim_enable_neomake
    call add(plugins, ['neomake/neomake', {'merged' : 0, 'loadconf' : 1 , 'loadconf_before' : 1}])
  elseif g:spacevim_enable_ale
    call add(plugins, ['w0rp/ale', {'merged' : 0, 'loadconf_before' : 1}])
  else
    call add(plugins, ['wsdjeg/syntastic', {'on_event': 'WinEnter', 'loadconf' : 1, 'merged' : 0}])
  endif

  return plugins
endfunction


function! SpaceVim#layers#checkers#config() abort
  let g:neomake_cursormoved_delay = get(g:, 'neomake_cursormoved_delay', 300)
  let g:ale_echo_delay = get(g:, 'ale_echo_delay', 300)

  call SpaceVim#mapping#space#def('nnoremap', ['e', 'c'], 'call call('
        \ . string(s:_function('s:clear_errors')) . ', [])',
        \ 'clear all errors', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'h'], '', 'describe a syntax checker', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'v'], '', 'verify syntax checker setup', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'n'], 'lnext', 'next-error', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'l'], 'lopen | wincmd w', 'toggle showing the error list', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'L'], 'lopen', 'toggle showing the error list', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'p'], 'lprevious', 'previous-error', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'N'], 'lNext', 'previous-error', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', 'v'], 'call call('
        \ . string(s:_function('s:verify_syntax_setup')) . ', [])',
        \ 'verify syntax setup', 1)
  call SpaceVim#mapping#space#def('nnoremap', ['e', '.'], 'call call('
        \ . string(s:_function('s:error_transient_state')) . ', [])',
        \ 'error-transient-state', 1)

  augroup SpaceVim_layer_checker
    autocmd!
    if g:spacevim_enable_neomake
      autocmd User NeomakeFinished nested
            \ let &l:statusline = SpaceVim#layers#core#statusline#get(1)

      " when move cursor, the error message will be shown below current line
      " after a delay
      autocmd CursorMoved * call <SID>neomake_cursor_move_delay()

      " when switch to Insert mode, stop timer and clear the signature
      if exists('##CmdLineEnter')
        autocmd InsertEnter,WinLeave,CmdLineEnter *
              \ call <SID>neomake_signatures_clear() | redraw
      else
        autocmd InsertEnter,WinLeave * call <SID>neomake_signatures_clear() | redraw
      endif
    elseif g:spacevim_enable_ale
      autocmd User ALELint 
            \ let &l:statusline = SpaceVim#layers#core#statusline#get(1)
    endif
  augroup END
endfunction

function! s:neomake_cursor_move_delay() abort
  call s:neomake_signatures_clear()
  let s:neomake_cursormoved_timer = timer_start(g:neomake_cursormoved_delay,
        \ function('s:neomake_signatures_current_error'))
endfunction

let s:last_echoed_error = ''
let s:clv = &conceallevel
function! s:neomake_signatures_current_error(...) abort
  call s:neomake_signatures_clear()
  let message = neomake#GetCurrentErrorMsg()
  if empty(message)
    if exists('s:last_echoed_error')
      unlet s:last_echoed_error
    endif
    return
  endif
  if exists('s:last_echoed_error')
        \ && s:last_echoed_error == message
    return
  endif
  let s:last_echoed_error = message
  set conceallevel=2
  if len(line('.') + 1) > len(message)
    let message = s:STRING.fill(message, len(line('.') + 1))
  endif
  call s:SIG.info(line('.') + 1, 1, message)
endfunction

function! s:neomake_signatures_clear() abort
  if exists('s:neomake_cursormoved_timer') && s:neomake_cursormoved_timer != 0
    call timer_stop(s:neomake_cursormoved_timer)
  endif
  let s:last_echoed_error = ''
  let &conceallevel = s:clv
  call s:SIG.clear()
endfunction

function! s:verify_syntax_setup() abort
  if g:spacevim_enable_neomake
    NeomakeInfo
  elseif g:spacevim_enable_ale
  else
  endif
endfunction

function! s:error_transient_state() abort
  if g:spacevim_enable_neomake
    let num_errors = neomake#statusline#LoclistCounts()
  elseif g:spacevim_enable_ale
    let counts = ale#statusline#Count(buffer_name('%'))
    let num_errors = counts.error + counts.warning + counts.style_error
          \ + counts.style_warning
  else
    let num_errors = 0
  endif
  if empty(num_errors)
    echo 'no buffers contain error message locations'
    return
  endif
  let state = SpaceVim#api#import('transient_state') 
  call state.set_title('Error Transient State')
  call state.defind_keys(
        \ {
        \ 'layout' : 'vertical split',
        \ 'left' : [
        \ {
        \ 'key' : 'n',
        \ 'desc' : 'next error',
        \ 'func' : '',
        \ 'cmd' : 'try | lnext | catch | endtry',
        \ 'exit' : 0,
        \ },
        \ ],
        \ 'right' : [
        \ {
        \ 'key' : ['p', 'N'],
        \ 'desc' : 'previous error',
        \ 'func' : '',
        \ 'cmd' : 'try | lprevious | catch | endtry',
        \ 'exit' : 0,
        \ },
        \ {
        \ 'key' : 'q',
        \ 'desc' : 'quit',
        \ 'func' : '',
        \ 'cmd' : '',
        \ 'exit' : 1,
        \ },
        \ ],
        \ }
        \ )
  call state.open()
endfunction

" function() wrapper
if v:version > 703 || v:version == 703 && has('patch1170')
  function! s:_function(fstr) abort
    return function(a:fstr)
  endfunction
else
  function! s:_SID() abort
    return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze__SID$')
  endfunction
  let s:_s = '<SNR>' . s:_SID() . '_'
  function! s:_function(fstr) abort
    return function(substitute(a:fstr, 's:', s:_s, 'g'))
  endfunction
endif

" TODO clear errors
function! s:clear_errors() abort
  sign unplace *
endfunction
