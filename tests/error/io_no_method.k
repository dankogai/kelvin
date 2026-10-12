// an IO's methods (#82)
let main():i32 {
    var f = IO.stdout
    f.append("x")
    return 0
}
// error: an IO has no method 'append': write, print, println, flush, close, read(n), seek(n), rewind and kill(signal), and the properties bytes, string, lines, byte, eof, position, count, fd, status, signal and pid; it is not copied
