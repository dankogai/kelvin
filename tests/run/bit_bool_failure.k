// !!n takes an integer 0 or 1 (#387): any other ends the program
let main():int32 {
    var n = 2
    println("before")
    let b = !!n
    println("never ", b)
    return 0
}
// out: before
// exit: 1
// err: kelvin: '!!' takes an integer 0 or 1, and this is neither
