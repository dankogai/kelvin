// an IO's methods (#82)
let main():i32 {
    var f = IO.stdout
    f.append("x")
    return 0
}
// error: an IO has no method 'append': write, flush, close and read(n), and the properties bytes, string and lines; it is not copied
