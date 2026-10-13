

### 139. `f.abspath` through the descriptor

> now add `f.abspath` via the descriptor when the path is gone

**Claude** added #105: where realpath of the path fails, or the IO has
no path, `f.abspath` asks the system what the open descriptor is
named, macOS's `F_GETPATH` or Linux's `/proc/self/fd`, so a file
renamed behind the IO answers by its new name and a removed one by the
name it had; a pipe, a closed IO, or another system still gives `""`.
Details are provisional P117.

There are 643 tests, and all pass with clang and with gcc 15.
