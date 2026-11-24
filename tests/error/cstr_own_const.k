// cstr const is a cstr that is itself const (#742), as T^ const is
let main():int32 {
    var s:cstr const := "a"
    println(s)
    s := "b"
    return 0
}
// error: 's' is a cstr const, a pointer that does not change: declare it without const to point it elsewhere
