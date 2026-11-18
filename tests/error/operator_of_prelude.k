// an operator of the prelude's own types is the prelude's (#606): a
// program's of the same types met it at link, a duplicate symbol, and no
// Kelvin. says which of two is meant, as Kelvin.name does of a function
let +(a:c64, b:c64):c64 { a }
let main():int32 {
    println(c64(1.0, 2.0) + c64(1.0, 1.0))
    return 0
}
// error: operator + of (c64, c64) is the prelude's, and a program defines no other of the same types (#606)
