// C11's _Alignof is spelled alignof, C23's name (#395)
let main():i32 {
    println(_Alignof(i64))
    return 0
}
// error: '_Alignof' is C11's spelling: Kelvin writes alignof(T), and a value's is x.align
