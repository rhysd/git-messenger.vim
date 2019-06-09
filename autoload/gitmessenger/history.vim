" Note: Index 0 means the latest entry of history

" interface BlameState {
"   commit: string;
"   contents: string[];
"   diff_file_to: string;
"   diff_file_from: string;
"   diff: 'none' | 'all' | 'current';
" }
"
" interface BlameHistory extends BlameState {
"   _index: number;
"   _history: BlameState[];
" }
"
" History of chain of `git blame` with contents.
"
" contents:
"   Lines of contents of popup
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
let s:history = { '_index': 0, '_history': [] }

" Create new empty history entry as the latest
function! s:history__push() dict abort
    " Note: copy() is necessary because the contents may be updated later
    " for diff
    " Note: 'commit' is a special key which will be never changed. This field
    " will be used for checking invariant state on saving the state
    let self._history += [{ 'commit': self.commit }]
    let self._index = len(self._history) - 1
endfunction
let s:history.push = funcref('s:history__push')

" Save current state to current history entry
function! s:history__save() dict abort
    if self._index > len(self._history)
        throw printf('FATAL: Invariant error on saving history. Index %d is out of range. Length of history is %d', self._index, len(self._history))
    endif

    let e = self._history[self._index]
    if self.commit !=# e.commit
        throw printf('FATAL: Invariant error on saving history. Current commit hash %s is different from commit hash in history %s', self.commit, e.commit)
    endif

    let e.diff = self.diff
    let e.contents = copy(self.contents)
    let e.diff_file_to = self.diff_file_to
    let e.commit = self.commit
    let e.diff_file_from = self.diff_file_from
endfunction
let s:history.save = funcref('s:history__save')

" Load specific history entry as current state
function! s:history__load(index) dict abort
    let e = self._history[a:index]
    " Note: copy() is necessary because the contents may be updated later
    " for diff. Without copy(), it modifies array in self.history directly
    " but that's not intended.
    let self.contents = copy(e.contents)
    let self.diff = e.diff
    let self.commit = e.commit
    let self.diff_file_to = e.diff_file_to
    let self.diff_file_from = e.diff_file_from
    let self._index = a:index
endfunction
let s:history._load = funcref('s:history__load')

function! s:history__history_no() dict abort
    return len(self._history)
endfunction
let s:history.history_no = funcref('s:history__history_no')

" Go back to older. Load older history entry to current history.
" Returns boolean which is true when older entry was found.
function! s:history__back() dict abort
    let next_index = self._index + 1

    call self.save()

    if len(self._history) <= next_index
        return v:false
    endif

    call self._load(next_index)
    return v:true
endfunction
let s:history.back = funcref('s:history__back')

" Go forward to newer. Load newer history entry to current state.
" Returns boolean which is true when newer entry was found.
function! s:history__forward() dict abort
    " Note: Index 0 is the latest entry
    let next_index = self._index - 1
    if next_index < 0
        return v:false
    endif

    call self.save()
    call self._load(next_index)
    return v:true
endfunction
let s:history.forward = funcref('s:history__forward')

function! gitmessenger#history#new(filepath) abort
    let h = deepcopy(s:history)
    let h.contents = []
    let h.diff_file_to = a:filepath
    let h.diff_file_from = a:filepath
    let h.diff = 'none'
    let h.commit = ''
    return h
endfunction
