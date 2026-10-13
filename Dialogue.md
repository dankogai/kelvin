

### 142. The operations straight

> now add `f.chmod` and the other operations straight too

**Claude** added #108: `f.chmod`, `f.chown`, `f.truncate`, `f.utime`,
`f.touch`, `f.remove` and `f.rename` give a `bool`, true when done,
and no `errno`, as `seek` and `kill` already did; the first five
through the descriptor, so they work on a file renamed or removed
behind the IO, the last two by the path while it is there, else by the
descriptor's name. `OS`'s of the same path still tell why. Details are
provisional P120.

There are 646 tests, and all pass with clang and with gcc 15.
