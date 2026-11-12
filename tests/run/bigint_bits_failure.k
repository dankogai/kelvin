// a BigInt's bit is at place 0 or more (#531): a value below ends the
// program, where a literal is an error
let main():int32 {
    var b = 5n
    var i = 2
    println(b.bits[i])
    i -= 5
    println(b.bits[i])
    println("never")
    return 0
}
// out: true
// exit: 1
// err: kelvin: a BigInt's bit is at place 0 or more, and this is -3
