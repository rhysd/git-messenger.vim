git-messenger.vim
=================

[git-messenger.vim][repo] is a Vim/Neovim plugin to reveal the hidden message from Git under the
cursor quickly. It shows the hisotry of commits under the cursor in popup window.

This plugin shows the message of the last commit in a 'popup window'. If the last commit is not
convenient, you can explore older commits in the popup window.

The popup window is implemented in

- Floating window on Neovim (0.4 or later)
- Preview window on Vim (8 or later) or Neovim (0.3 or earlier)

The floating window is definitely recommended since it can shows the information near the cursor.

This plugin supports both Neovim and Vim (8 or later). And I wrote
[a Japanese blogpost for this plugin](https://rhysd.hatenablog.com/entry/2019/03/10/230119).



## Why?

When you're modifying unfamiliar codes, you would sometimes wonder 'why was this line added?' or
'why this value was chosen?' in the source code. The answer sometimes lays in a commit message,
especially in message of the last commit which modifies the line.



## Screenshot

- Show popup window with Neovim v0.4.0-dev:

<img alt="screencast" src="https://github.com/rhysd/ss/blob/master/git-messenger.vim/demo.gif?raw=true" width=763 height=556 />

- Screencast for exploring older commits:

<img alt="history" src="https://github.com/rhysd/ss/blob/master/git-messenger.vim/history.gif?raw=true" width=510 height=252 />



## Installation

If you use any package manager, please follow its instruction.

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'rhysd/git-messenger.vim'
```

With [dein.vim](https://github.com/Shougo/dein.vim):

```vim
call dein#add('rhysd/git-messenger.vim', {
            \   'lazy' : 1,
            \   'on_cmd' : 'GitMessenger',
            \   'on_map' : '<Plug>(git-messenger',
            \ })
```

With [minpac](https://github.com/k-takata/minpac):

```vim
call minpac#add('rhysd/git-messenger.vim')
```

When you're using Vim's builtin packager, please follow instruction at `:help pack-add`.

To enable a floating window support, you need to install Neovim 0.4 or later. The version is not
yet released, so you need to install Neovim by building from source at this point. If you use macOS,
it's quite easy with Homebrew.

```
$ brew install neovim --HEAD
```

To check if Neovim's floating window feature is available, try `:checkhealth`.


## Usage

Briefly, move cursor to the position and run `:GitMessenger` or `<Leader>gm`. If you see an error
message, please try [health check](#health-check)

### Commands

```
:GitMessenger
```

Behavior of this command is depending on the situation. You can do every operations only with this
mapping.

- Normally, it opens a popup window with the last commit message
- When a popup window is already open, it moves cursor into the window
- When a cursor is within a popup window, it closes the window

It opens a popup window with the last commit message which modified the line at cursor. The popup
window shows following contents:

- **History:** `History: {page number}` In popup window, `o`/`O` navigates to previous/next commit.
- **Commit:** `Commit: {hash}` The commit hash
- **Author:** `Author: {name}<{email}>` Author name and mail address of the commit
- **Committer:** `Committer: {name}<{email}>` Committer name and mail address of the commit when
  committer is different from author
- **Summary:** First line after `Committer:` header line is a summary of commit
- **Body:** After summary, commit body is put (if the commit has body)

The popup window will be automatically closed when you move the cursor so you don't need to close
it manually.

Running this command while a popup window is open, it moves the cursor into the window.
This behavior is useful when the commit message is too long and window cannot show the whole content.
By moving the cursor into the popup window, you can see the rest of contents by scrolling it.
You can also see the older commits.

Following mappings are defined within popup window.

| Mapping | Description                                          |
|---------|------------------------------------------------------|
| `q`     | Close the popup window                               |
| `o`     | **o**lder. Back to older commit at the line          |
| `O`     | Opposite to `o`. Forward to newer commit at the line |
| `?`     | Show mappings help                                   |

```
:GitMessengerClose
```

Though a popup window is automatically closed by default, it closes the popup window explicitly. It
is useful when you set `g:git_messenger_close_on_cursor_moved` to `v:false`.

### Mappings

Some `<Plug>` mappings are available to operate a popup window. They can be mapped to your favorite
key sequences. For example:

```vim
nmap <Leader>m <Plug>(git-messenger)
```

I recommend to map `<Plug>(git-messenger)` in your `vimrc` or use default `<Leader>gm` mapping.

- `<Plug>(git-messenger)`: The same as running `:GitMessenger` command.
- `<Plug>(git-messenger-close)`: The same as running `:GitMessengerClose` command.
- `<Plug>(git-messenger-into-popup)`: Moves the cursor into the popup window. It's useful when you want to scroll the content and close the window.
- `<Plug>(git-messenger-scroll-down-1)`: Scroll down the popup window by 1 line directly
- `<Plug>(git-messenger-scroll-up-1)`: Scroll up the popup window by 1 line directly
- `<Plug>(git-messenger-scroll-down-page)`: Scroll down the popup window by 1 page directly
- `<Plug>(git-messenger-scroll-up-page)`: Scroll up the popup window by 1 page directly
- `<Plug>(git-messenger-scroll-down-half)`: Scroll down the popup window by half page directly
- `<Plug>(git-messenger-scroll-up-half)`: Scroll up the popup window by half page directly

If `g:git_messenger_no_default_mappings` is not set to `v:true`, this plugin also defines
following default mapping.

```vim
nmap <Leader>gm <Plug>(git-messenger)
```

### Variables

Some global variables are available to configure the behavior of this plugin.

#### `g:git_messenger_close_on_cursor_moved` (Default: `v:true`)

When this value is set to `v:false`, a popup window is no longer closed automatically when moving a
cursor after the window is shown up.

#### `g:git_messenger_git_command` (Default: `"git"`)

`git` command to retrieve commit messages. If your `git` executable is not in `$PATH` directories,
please specify the path to the executable.

#### `g:git_messenger_no_default_mappings` (Default: `v:true`)

When this value is set to `v:false`, it does not define any key mappings. `<Plug>` mappings are
still defined since they don't make any conflict with existing mappings.

#### `g:git_messenger_into_popup_after_show` (Default: `v:true`)

When this value is set to `v:false`, running `:GitMessenger` or `<plug>(git-messenger)` again after
showing a popup does not move the cursor in the window.

#### `g:git_messenger_always_into_popup` (Default: `v:false`)

When this value is set to `v:true`, the cursor goes into a popup window when running `:GitMessenger`
or `<Plug>(git-messenger)`.

#### `g:git_messenger_preview_mods` (Deafult: `""`)

This variable is effective only when opening preview window (on Neovim (0.3.0 or earlier) or Vim).

Command modifiers for opening preview window. The value will be passed as prefix of `:pedit` command.
For example, setting `"botright"` to the variable opens a preview window at bottom of the current
window. Please see `:help <mods>` for more details.

### Popup window highlight

This plugin sets sensible highlight colors to popup menu for light and dark colorschemes by default.
However, it may not match to your colorscheme. In the case, you can specify your own colors to
popup window in `nvim/init.vim` by defining highlights as follows.. This is only available on
Neovim.

Example:

```vim
" Header such as 'Commit:', 'Author:'
hi gitmessengerHeader term=None guifg=#88b8f6 ctermfg=111

" Commit hash at 'Commit:' header
hi gitmessengerHash term=None guifg=#f0eaaa ctermfg=229

" History number at 'History:' header
hi gitmessengerHistory term=None guifg=#fd8489 ctermfg=210

" Normal color. This color is the most important
hi gitmessengerPopupNormal term=None guifg=#eeeeee guibg=#333333 ctermfg=255 ctermbg=234

" Color of 'end of buffer'. To hide '~' in popup window, I recommend to use the same background
" color as gitmessengerPopupNormal.
hi gitmessengerEndOfBuffer term=None guifg=#333333 guibg=#333333 ctermfg=234 ctermbg=234
```

### Health Check

This plugin supports a health checker on Neovim. When you see some error, please run `:checkhealth`
to check your environment is ready for use of this plugin.

On Vim, please install [vim-healthcheck](https://github.com/rhysd/vim-healthcheck) and run
`:CheckHealth`. It's a plugin to run `:checkhealth` on Vim.



## License

Distributed under [the MIT License](LICENSE)

[repo]: https://github.com/rhysd/git-messenger.vim
