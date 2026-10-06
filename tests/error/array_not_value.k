// an array literal is an initializer, not a value: a compound literal is (#48)
let first(a:const i64[]):i64 { a[0] }
let main():i32 {
    println(first([1, 2]))
    return 0
}
// error: an array is not a value here: write a compound literal, as in '(i32[])[1, 2, 3]' (#48)
