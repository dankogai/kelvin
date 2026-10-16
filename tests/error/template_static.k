// error: a template literal with ${...} is made at run time, and a static's initializer must be constant
let main():int32 {
    let n:int64 = 1
    static let s:cstr := `n=${n}`
    println(s)
    return 0
}
