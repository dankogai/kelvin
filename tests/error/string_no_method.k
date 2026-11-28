// a method a String has not is told with what it has (#787)
let main():int32 {
    var s:String = "a"
    s.frob()
    return 0
}
// error: a String has no method 'frob': append, clear, reserve, compact, copy, escape, unescape, find, has, starts, ends, trim and gather, and the properties count, isEmpty, bytes and cstr
