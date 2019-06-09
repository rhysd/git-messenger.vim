" Note: Index 0 means the latest entry of history

" interface State {
"   contents: string[];
"   blame_file: string;
"   diff_file_to: string;
"   diff_file_from: string;
"   diff: 'none' | 'all' | 'current';
"   commit: string;
"   _index: number;
"   _history: {
"     commit: string;
"     contents: string[];
"     blame_file: string;
"     diff_file_to: string;
"     diff_file_from: string;
"     diff: 'none' | 'all' | 'current';
"   }[];
" }
"
" contents:
"   Lines of contents of popup
" blame_file:
"   File path given to `git blame`. This can be relative to root of repo
" diff_file_to:
"   File path for diff. It represents the file path after the commit.
"   When the file was renamed while the commit, it is different from 'diff_file_from'
" diff_file_from:
"   File path for diff. It represents the file path before the commit.
"   When the file was renamed while the commit, it is different from 'diff_file_to'
" diff:
"   Diff type. Please see document for g:git_messenger_include_diff
" commit:
"   Commit hash of the commit
" _index:
"   Index of history which indicates current state. 0 means the latest history
" _history:
"   History of chain of blame entries. Latter is older.
let s:state = { '_index': 0, '_history': []}

" Create new empty history entry as the latest
function! s:state__push() dict abort
    " Note: copy() is necessary because the contents may be updated later
    " for diff
    " Note: 'commit' is a special key which will be never changed. This field
    " will be used for checking invariant state on saving the state
    let self._history += [{ 'commit': self.commit }]
    let self._index = len(self._history) - 1
endfunction
let s:state.push = funcref('s:state__push')

" Save current state to current history entry
function! s:state__save() dict abort
    if self._index > len(self._history)
        throw printf('FATAL: Invariant error on saving history. Index %d is out of range. Length of history is %d', self._index, len(self._history))
    endif

    let h = self._history[self._index]
    if self.commit !=# h.commit
        throw printf('FATAL: Invariant error on saving history. Current commit hash %s is different from commit hash in history %s', self.commit, h.commit)
    endif

    let h.diff = self.diff
    let h.contents = copy(self.contents)
    let h.diff_file_to = self.diff_file_to
    let h.commit = self.commit
    let h.diff_file_from = self.diff_file_from
endfunction
let s:state.save = funcref('s:state__save')

" Load specific history entry as current state
function! s:state__load(index) dict abort
    let h = self._history[a:index]
    " Note: copy() is necessary because the contents may be updated later
    " for diff. Without copy(), it modifies array in self.history directly
    " but that's not intended.
    let self.contents = copy(h.contents)
    let self.diff = h.diff
    let self.commit = h.commit
    let self.diff_file_to = h.diff_file_to
    let self.diff_file_from = h.diff_file_from
    let self._index = a:index
endfunction
let s:state._load = funcref('s:state__load')

function! s:state__history_no() dict abort
    return len(self._history)
endfunction
let s:state.history_no = funcref('s:state__history_no')

" Go back to older. Load older history entry to current state.
" Returns boolean which is true when older entry was found.
function! s:state__back() dict abort
    let next_index = self._index + 1

    call self.save()

    if len(self._history) <= next_index
        return v:false
    endif

    call self._load(next_index)
    return v:true
endfunction
let s:state.back = funcref('s:state__back')

" Go forward to newer. Load newer history entry to current state.
" Returns boolean which is true when newer entry was found.
function! s:state__forward() dict abort
    " Note: Index 0 is the latest entry
    let next_index = self._index - 1
    if next_index < 0
        return v:false
    endif

    call self.save()
    call self._load(next_index)
    return v:true
endfunction
let s:state.forward = funcref('s:state__forward')

function! gitmessenger#state#new(filepath) abort
    let s = deepcopy(s:state)
    let s.contents = []
    let s.blame_file = a:filepath
    let s.diff_file_to = a:filepath
    let s.diff_file_from = a:filepath
    let s.diff = 'none'
    let s.commit = ''
    return s
endfunction
