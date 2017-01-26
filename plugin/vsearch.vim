" ============================================================================
" File:        vsearch.vim
" Description: Search & Replace plugin for VIM
" Author:      Mo Morsi <mo at morsi dot org>
" Version:     0.4.2
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

if !exists("g:vsearch_find")
  let g:vsearch_find = "/usr/bin/find"
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

function! s:ValidateFind()
  if !executable(g:vsearch_find)
    echohl ErrorMsg
    echo "vsearch requires find"
    return 0
  endif
  return 1
endfunc


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
  silent exec 'grep! ' . join(a:000)
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
  echohl None
  for d in getqflist()
    echo bufname(d.bufnr) ':' d.lnum '=' d.text "=>" substitute(d.text, l:srch, l:rplc, 'g')
  endfor

  " prompt user for confirmation
  let prompt = input("Make Changes (y/n)? ")
  if prompt == 'y' || prompt == 'Y'
    echo " "

    " cleanup for shell
    let l:es = substitute(l:srch, '/', '\\/', 'g')
    let l:es = substitute(l:es,   '"', '\\"', 'g')
    let l:er = substitute(l:rplc, '/', '\\/', 'g')
    let l:er = substitute(l:er,   '"', '\\"', 'g')

    " run replacement and check result
    let result = system(g:vsearch_find . ' ' . l:file . ' -exec ' . g:vsearch_grep . ' -i "s/'. l:es .'/'. l:er .'/g" {} \;')
    if v:shell_error != 0
      " TODO rollback mechanism (?)
      echohl ErrorMsg
      echo "Error During Replace"
      echo result
      return
    endif

    " TODO handle buffers containing modified files (refresh here, or detect above & quit before sed)
  endif
endfunc


"======================
" Command Definitions "
"======================
if !exists('g:vsearch_no_commands')
  command! -nargs=* VSearch  :call VSearch(<f-args>)
  command! -nargs=* VReplace :call VReplace(<f-args>)
endif
