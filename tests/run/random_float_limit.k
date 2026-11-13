// T.random(start, lim) of a start not below its limit, or of a NaN, has
// no number to give, and ends the program, said (#547)
let main():int32 {
    let lim = 1.0
    println("before")
    println(f64.random(2.0, lim))
    return 0
}
// out: before
// exit: 1
// err: kelvin: 'T.random(start, lim)' takes a start below its limit, both finite, and this has no number between them
