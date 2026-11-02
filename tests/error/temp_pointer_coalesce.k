// the right of ?? is made only where the left has no value, so a pointer
// into a temporary in it is not held for the call around it (#437)
let main():int32 {
    let s:cstr? = none
    println(s ?? String(1).cstr)
    return 0
}
// error: this is a pointer into a String that an expression gives, which is freed once the expression is done: bind it to a variable first
