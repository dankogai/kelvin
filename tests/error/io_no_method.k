// an IO's methods (#82)
let main():i32 {
    var f = IO.stdout
    f.append("x")
    return 0
}
// error: an IO has no method 'append': see documents/io.md for write, print, println, flush, close, read(n), seek(n), rewind, kill, glob, chmod, chown, truncate, remove, rename, utime, touch and join, and its properties; it is not copied
