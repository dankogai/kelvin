// Kelvin.sqrt chooses among the prelude's overloads alone (#600): the
// program's own sqrt of text is none of them
let sqrt(s:cstr):i64 { 0 }
let main():int32 {
    println(sqrt("x"), Kelvin.sqrt("x"))
    return 0
}
// error: Kelvin.sqrt(...) fits none of its
