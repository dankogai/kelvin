// a bit of a BigInt is set with a bool (#531), as an integer's is
let main():int32 {
    var b = 5n
    b.bits[1] = 1
    return 0
}
// error: a bit of a BigInt is set with a bool, and this is i64: '!!n' makes one of an integer 0 or 1
