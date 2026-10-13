

### 141. `f.bytes` and `f.string` straight

> now add `f.bytes` and `f.string` straight too

**Claude** added #107: `f.bytes` is the rest of the file as a `Bytes`
and `f.string` as a `String`, with no Result, since the file was there
to open; a stream that stops answering gives what was read before.
Text that is not UTF-8 ends `f.string` with a message, as a line of
`f.lines` already did, so a program that may meet such text reads
`f.bytes` and asks `b.isUTF8`. Details are provisional P119.

There are 645 tests, and all pass with clang and with gcc 15.
