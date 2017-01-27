" ============================================================================
" File:        vsearch.vim
" Description: Search & Replace plugin for VIM
" Author:      Mo Morsi <mo at morsi dot org>
" Version:     0.4.3
" Last Change: 01/26/17
" License:     MIT
" ============================================================================


" ============================================================================
" Init
" ============================================================================
if exists('g:loaded_vsearch')
  finish
endif
let g:loaded_vsearch = 1

if !exists("g:vsearch_grep")
  let g:vsearch_grep = split(&grepprg)[0]
endif

if !exists("g:vsearch_sed")
  let g:vsearch_sed = "/usr/bin/sed"
endif

function! s:ValidateGrep()
  if !executable(g:vsearch_grep)
    echohl ErrorMsg
    echo "vsearch requires grep"
    return 0
  endif
  return 1
endfunc

function! s:ValidateSed()
  if !executable(g:vsearch_sed)
    echohl ErrorMsg
    echo "vsearch requires sed"
    return 0
  endif
  return 1
endfunc

" few util functions

function! GetBufferList()
  redir =>buflist
  silent! ls!
  redir END
  return split(buflist, '\n')
endfunction

function! GetActiveBufferList()
  redir =>buflist
  silent! ls! a
  redir END
  return split(buflist, '\n')
endfunction

function! GetActiveBufferNames()
  let l:r = []
  for a in GetActiveBufferList()
    call add(l:r, substitute(split(a)[2], '"', '', 'g'))
  endfor
  return l:r
endfunction

function! Strip(input_string)
  return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction


" ============================================================================
" Invoke grep & open the quick buffer.
" Specify arguments as you would to the standard grep command:
"   :VSearch what_to_look_for file_to_search
"   :VSearch -r foobar directory/
" ============================================================================
function! VSearch(...)
  if !s:ValidateGrep()
    return
  endif

  " used grep! to load results but not jump to first one
  silent exec 'grep! -r ' . join(a:000)
  copen
endfunc


" ============================================================================
" Find & replace mechanism using grep and sed.
" Takes 2 or 3 arguments:
"   - search pattern and replacement (file path will be cwd)
"   - search pattern, replacement, and file path
"
" Uses grep to search for files at the specified path
" (recursively) before staging and displaying changes,
" prompting the user for final confirmation.
"
"   :VReplace foo bar        # replaces foo with bar in all files
"                            # in current dir and subdirs
"   :VReplace foo bar subdir # replace foo with bar in particular file/subdir
"
"    # replace 'some' with 'thing' in multiple files
"   :VReplace some thing file1 file2 file_regex...
" ============================================================================
function! VReplace(...)
  if !s:ValidateGrep() || !s:ValidateSed() || !s:ValidateFind()
    return
  endif


  let l:srch = '' " search
  let l:rplc = '' " replace
  let l:file = '' " file(s)

  if a:0 < 2
    " interactive mode
    let l:srch = input("Search: ")
    let l:rplc = input("Replace: ")
    let l:file = input("File(s): ")

  else
    let l:srch = a:1
    let l:rplc = a:2

    " accumulate specified files...
    if a:0 > 2
      let l:i = 2
      while l:i < a:0
        let l:file  = l:file . ' ' . a:000[i]
        let l:i += 1
      endwhile

    " ... or set to default
    else
      let l:file = getcwd()
    endif
  endif

  " verify input
  if l:srch == '' || l:rplc == '' || l:file == ''
    echohl ErrorMsg
    echo " "
    echo "Must specify search, replace, & path"
    let result = input("Press any key to continue")
    return
  endif

  " runs grep / result in quickfix
  new
  silent exec g:vsearch_grep . ' -r ' . l:srch . ' ' . l:file
  quit

  " verify grep succeeded
  if len(getqflist()) == 0
    echohl ErrorMsg
    echo "No results"
    let result = input("Press any key to continue")
    return
  endif

  "" verify target file
  if len(getqflist()) == 1 && getqflist()[0].text =~ "No such file or directory"
    echohl ErrorMsg
    echo "Invalid path specified"
    let result = input("Press any key to continue")
    return
  endif

  " display implending change
  let l:files     = []
  let l:files_str = ""
  echohl None
  for d in getqflist()
    let l:bufname = bufname(d.bufnr)

    " XXX
    if l:bufname =~ 'NERD_tree.*'
      continue
    endif

    echo bufname ':' d.lnum '=' d.text "=>" substitute(d.text, l:srch, l:rplc, 'g')
    let l:files_str = l:files_str . ' ' . bufname
    call add(l:files, bufname)
  endfor


  " prompt user for confirmation
  let prompt = Strip(input("Make Changes (y/n)? "))
  if prompt == 'y' || prompt == 'Y'
    echo " "

    " detect if any open buffers contains file to change
    let l:verify_overwrite = 0
    for a in GetActiveBufferNames()
      for f in l:files
        if a == f
          echoh1 WarningMsg
          echo a ' is currently being edited'
          let l:verify_overwrite = 1
        endif
      endfor
    endfor

    if l:verify_overwrite
      let prompt = Strip(input("Overwrite (y/n)? "))
    endif

    if prompt == 'y' || prompt == 'Y'
      " cleanup for shell
      let l:es = substitute(l:srch, '/', '\\/', 'g')
      let l:es = substitute(l:es,   '"', '\\"', 'g')
      let l:er = substitute(l:rplc, '/', '\\/', 'g')
      let l:er = substitute(l:er,   '"', '\\"', 'g')

      " run replacement and check result
      let result = system(g:vsearch_sed . ' -i "s/'. l:es .'/'. l:er .'/g" ' . l:files_str)
      if v:shell_error != 0
        " TODO rollback mechanism (?)
        "      (perhaps integrate w/ vim 'undo' system)
        echohl ErrorMsg
        echo "Error During Replace"
        echo result
        return
      endif

      " TODO 'smart' indentation mechanism ?
    endif
  endif
endfunc


"======================
" Command Definitions "
"======================
if !exists('g:vsearch_no_commands')
  command! -nargs=* VSearch  :call VSearch(<f-args>)
  command! -nargs=* VReplace :call VReplace(<f-args>)
endif
