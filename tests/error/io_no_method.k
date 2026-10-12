// an IO's methods (#82)
let main():i32 {
    var f = IO.stdout
    f.append("x")
    return 0
}
// error: an IO has no method 'append': write, print, println, flush, close, read(n), seek(n) and rewind, and the properties bytes, string, lines, eof, position and count; it is not copied
