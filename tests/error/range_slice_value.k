// a slice is written with its bounds, not a Range value (#373)
let main():int32 {
    let r = 1..<2; let xs = $[1, 2, 3]; let ys = xs[r]
    return 0
}
// error: a slice is written 'xs[lo..<hi]', and a Range value does not index: write its bounds
