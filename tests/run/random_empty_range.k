// T.random(r) of an empty range has no value to give, and ends the
// program, said, as Swift's does (#547)
let main():int32 {
    let n = 5
    println("before")
    println(i64.random(n..<n))
    return 0
}
// out: before
// exit: 1
// err: kelvin: 'T.random(r)' takes a range with a value in it, and this one is empty
