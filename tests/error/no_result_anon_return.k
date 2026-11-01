// an anonymous function with no result returns no value either (#427)
// error: this function has no result, so it returns no value: write its result's type, as in '{ (...):T in ... }', or 'return' alone
let main():int32 {
    let g := { (n:int64) in
        if n < 0 { return 3 }
        println(n)
    }
    g(2)
    return 0
}
