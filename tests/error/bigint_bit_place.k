// a bit's place in a BigInt is 0 or more (#531): a literal below is an error
let main():int32 {
    var b = 5n
    println(b.bits[-1])
    return 0
}
// error: a bit's place in a BigInt is 0 or more, and this is -1
