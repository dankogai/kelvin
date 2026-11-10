// a program with a type of its own named BigInt keeps it, and brings in no
// prelude BigInt (#504, #507)
struct BigInt { digits: cstr }
let main():int32 {
    let b:BigInt = {"123"}
    println(b.digits)
    return 0
}
// out: 123
