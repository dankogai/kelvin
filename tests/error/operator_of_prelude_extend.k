// so in an extend of the prelude's type (#606), and of a BigInt's ==
extend BigInt {
    static let ==(a:Self, b:Self):bool { true }
}
let main():int32 {
    println(1n == 2n)
    return 0
}
// error: operator == of (BigInt, BigInt) is the prelude's, and a program defines no other of the same types (#606)
