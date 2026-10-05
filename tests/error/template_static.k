// error: a template literal with ${...} is made at run time, and a static's initializer must be constant
main():i32 {
    let n:i64 = 1
    static let s:cstr := `n=${n}`
    println(s)
    return 0
}
