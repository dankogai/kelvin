// a method with no result returns no value either (#427)
// error: 'pt.show' has no result, so it returns no value: write its result's type, as in 'let pt.show(...):T', or 'return' alone
struct pt { x:int64 }
let pt.show() {
    if .x < 0 { return 1 }
    println(.x)
}
let main():int32 {
    let p:pt = {1}
    p.show()
    return 0
}
