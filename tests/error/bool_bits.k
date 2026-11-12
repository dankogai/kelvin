// a bool has no bits (#530): it is one
let main():int32 {
    let b = true
    println(b.bits)
    return 0
}
// error: '.bits' is an integer's bits, each a bool, and this is a bool
