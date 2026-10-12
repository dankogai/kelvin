// an IO reads a byte, an i64 or an f64 (#85)
let main():i32 {
    var f = IO.stdin
    var n = f.i32
    return 0
}
// error: an IO reads a byte with '.byte', an integer with '.i64' and a float with '.f64', not '.i32'
