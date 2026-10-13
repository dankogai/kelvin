

### 143. `IO(path, mode)` straight

> now add `IO(path, mode)` straight too

**Claude** noted that the open is the call that checks a path, so with
no Result something else must carry the errno, and asked which shape:
an IO holding its error, ending the program, or keeping the Result.
The user chose the first. #109: `IO(path, mode)` and `IO(fd, mode)`
give the IO; `f.error` is the open's `errno`, 0 when it opened, and
such an IO is as a closed one, with the reason in the message should
it be read by `f.lines` or written to. `IO.popen`, `IO.exec` and
`IO.pipe()` stay Results until asked. Details are provisional P121.

There are 648 tests, and all pass with clang and with gcc 15.
