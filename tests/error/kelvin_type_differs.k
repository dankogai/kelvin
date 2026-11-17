// the program's own BigInt and the prelude's are two types (#600), and
// a message names each as the program writes it
struct BigInt { digits: cstr }
let count(b:BigInt):i64 { 1 }
let main():int32 {
    println(count(2n))
    return 0
}
// error: 'b' of 'count' is a BigInt, and this is Kelvin.BigInt
