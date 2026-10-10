// a slice to the end is written with ... (#68)
let main():i32 {
    var xs = $[1, 2]
    var y = xs[1..<]
    return 0
}
// error: a slice to the end is written [lo...]; '..<' needs an end
