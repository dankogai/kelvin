

### 144. The processes and the pipe straight

> now add `IO.popen`, `IO.exec` and `IO.pipe()` straight too

**Claude** added #110: `IO.popen` and `IO.exec` give the IO, with
`f.error` what the exec failed with, `ENOENT` for a program not found,
and `IO.pipe()` the pair `{reader: IO, writer: IO}`, both ends carrying
the error of a pipe that could not be made. Nothing of `IO` is a
Result any more. Details are provisional P122.

There are 649 tests, and all pass with clang and with gcc 15.
