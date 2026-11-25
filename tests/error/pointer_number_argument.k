// a number where a pointer parameter goes (#760), as a declaration's
let first(p:int64^):int64 { p^ }
let main():int32 {
    println(first(5))
    return 0
}
// error: 'p' of 'first' is an i64^, and this is a number
