// BigInt([b, ...]) is of bools (#531), as an integer type's is
let main():int32 {
    println(BigInt([true, 1]))
    return 0
}
// error: BigInt([b, ...]) is of bools, place 0 first, and this is i64
