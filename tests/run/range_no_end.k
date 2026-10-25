// a Range without an end has no end to walk to (#373): '.map' and its kin
// of one end the program, which '.prefix' and '.lazy' would not
let ends(lo:int64):Range { return lo... }
let main():int32 {
    let e = ends(7)
    println(e.prefix(2).map { $0 })
    println(e.map { $0 })
    return 0
}
// out: [7, 8]
// exit: 1
// err: kelvin: this Range has no end, and '.map' walks one to its end: take its first few, '.prefix(n)'
