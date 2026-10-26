// a Bits has value and flip (#387)
let main():int32 {
    let bv = Bits()
    println(bv.count)
    return 0
}
// error: a Bits has value, flip, cstr, size, type and typename, and '.count' is none of them: a bit is 'bv[n]'
