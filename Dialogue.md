

### 140. The rest of an IO's attributes straight

> now add `f.stat` straight to the rest of `IO`'s attributes

**Claude** added #106: `f.listdir`, `f.walk` and `f.glob(pattern)`
give an `Array<String>` with no Result, since the directory was there
to open; of the path while it is there, else of the descriptor's name,
so a directory renamed behind the IO still answers. An IO that is no
readable directory gives none. The operations, `chmod` and its kin,
stay 0 or `errno`, and `f.bytes` and `f.string` stay Results, as
contents with real errors. Details are provisional P118.

There are 644 tests, and all pass with clang and with gcc 15.
