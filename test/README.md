### How to Run tests

```
$ cd /path/to/git-messenger.vim
$ git clone https://github.com/thinca/vim-themis.git
$ THEMIS_VIM=nvim ./vim-themis/bin/themis test/nvim.vimspec
```

### How to run guard

Install [guard][] and [guard-shell][] as prerequisites.

```
$ guard -G test/Guardfile
```

It watches your file changes and runs tests automatically.

[guard]: https://github.com/guard/guard
[guard-shell]: https://github.com/guard/guard-shell
