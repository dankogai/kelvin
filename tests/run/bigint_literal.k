// 123n, 0xffn and 0b101n are BigInts (#508), as JS writes them: an
// integer's digits and an n, which become BigInt("123", 10), the prelude's
let main():int32 {
    let a = 123n
    let b = 0xffn
    let c = 0b101n
    let big = 1n << 100
    println(a, " ", b, " ", c, " ", big, " ", -5n, " ", 0n, " ", 2n * 3 + 1n)
    println(123456789012345678901234567890n % 97n, " ", 0xFFFFFFFFFFFFFFFFFFn.text(16), " ", 18446744073709551616n.u64)
    var f = 1n
    for i in 1...25 { f *= i }
    println(f, " ", f == 15511210043330985984000000n, " ", 5n.text(2))
    return 0
}
// out: 123n 255n 5n 1267650600228229401496703205376n -5n 0n 7n
// out: 52n ffffffffffffffffff 0
// out: 15511210043330985984000000n true 101
