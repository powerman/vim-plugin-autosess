" Maintainer: Alex Efros <powerman-asdf@ya.ru>
" Version: 1.2.1
" Last Modified: 2015-09-16
" License: This file is placed in the public domain.
" URL: http://www.vim.org/scripts/script.php?script_id=3883
" Description: Auto save/load sessions

if exists('g:loaded_autosess') || &cp || version < 700
	finish
endif
let g:loaded_autosess = 1


if !exists('g:autosess_dir')
	let g:autosess_dir   = '~/.vim/autosess/'
endif
let s:session_file  = substitute(getcwd(), '/', '%', 'g').'.vim'

autocmd VimEnter *		if v:this_session == '' | let v:this_session = expand(g:autosess_dir).'/'.s:session_file | endif
autocmd VimEnter * nested	if !argc()  | call AutosessRestore() | endif
autocmd VimLeave *		if !v:dying | call AutosessUpdate()  | endif


" 1. If 'swap file already exists' situation happens while restoring
" session, then Vim will hang and must be killed with `kill -9`. Looks
" like Vim bug, bug report was sent.
" 2. Trying to open such file as 'Read-Only' will fail because previous
" &readonly value will be restored from session data.
" 3. Buffers with &buftype 'quickfix' or 'nofile' will be restored empty,
" so we can get rid of them here to avoid doing this manually each time.
function AutosessRestore()
	if s:IsModified()
		return s:Error('Some files are modified, please save (or undo) them first')
	endif
	bufdo bdelete
	if filereadable(v:this_session)
		augroup AutosessSwap
		autocmd SwapExists *		call s:SwapExists()
		autocmd SessionLoadPost *	call s:FailIfSwapExists()
		silent execute 'source ' . fnameescape(v:this_session)
		autocmd!
		augroup END
		for bufnr in filter(range(1,bufnr('$')), 'getbufvar(v:val,"&buftype")!~"^$\\|help"')
			execute bufnr . 'bwipeout!'
		endfor
	endif
endfunction

function AutosessUpdate()
	if !isdirectory(expand(g:autosess_dir))
		call mkdir(expand(g:autosess_dir), 'p', 0700)
	endif

	if s:OnlyOneEmptyWindowRemains()
		" allow user to delete session by deleting all buffers
		call delete(v:this_session)
	elseif (s:WinNr() >= 1 && !&diff)
		execute 'mksession! ' . fnameescape(v:this_session)
	endif
endfunction

function s:OnlyOneEmptyWindowRemains()
	if (
		\ tabpagenr('$') == 1
		\ && winnr('$') == 1
		\ && line('$') == 1
		\ && col('$') == 1
	\)
		return 1
	else
		return 0
	endif
endfunction


function s:Error(msg)
	echohl ErrorMsg
	echo a:msg
	echohl None
endfunction

function s:IsModified()
	for i in range(1, bufnr('$'))
		if bufexists(i) && getbufvar(i, '&modified')
			return 1
		endif
	endfor
	return 0
endfunction

function s:WinNr()
	let winnr = 0
	for i in range(1, winnr('$'))
		let ft = getwinvar(i, '&ft')
		if ft != 'qf'
			let winnr += 1
		endif
	endfor
	return winnr
endfunction

function s:SwapExists()
	let s:swapname  = v:swapname
	let v:swapchoice = 'o'
endfunction

function s:FailIfSwapExists()
	if exists('s:swapname')
		call s:Error('Swap file "'.s:swapname.'" already exists!'."\n".
			\ 'Autosess: failed to restore session, exiting.')
		qa!
	endif
endfunction
