// error: a template literal with ${...} is made at run time, and a global's initializer must be constant
let n:i64 = 1
let text:cstr := `n is ${n}`
let main():i32 {
    println(text)
    return 0
}
