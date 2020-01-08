### How to Run tests

Setup:

```
$ cd /path/to/git-messenger.vim
$ git clone https://github.com/thinca/vim-themis.git
```

Run tests on `nvim`:

```
$ THEMIS_VIM=nvim ./vim-themis/bin/themis test/all.vimspec
```

Run tests on `vim`:

```
$ ./vim-themis/bin/themis test/all.vimspec
```

### How to run guard

Install [guard][] and [guard-shell][] as prerequisites.

```
$ guard -G test/Guardfile
```

It watches your file changes and runs tests automatically.

### How to take coverage

Set `$THEMIS_PROFILE` to take profiler log.

```
$ THEMIS_PROFILE=profile.txt ./vim-themis/bin/themis test/all.vimspec
```

It generates `profile.txt`. And run [covimerage][] to make a coverage file for `coverage` command.

```
$ covimerage write_coverage profile.txt
$ coverage report
```

[guard]: https://github.com/guard/guard
[guard-shell]: https://github.com/guard/guard-shell
[covimerage]: https://github.com/Vimjas/covimerage
