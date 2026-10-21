// error: this is a pointer into a String that an expression gives, which is freed once the expression is done: bind it to a variable first
let main():int32 {
    let p := $"x".cstr
    println(p)
    return 0
}
