// T(&s) of a String or a Bytes by reference reads its text, as T(s)
// does (#88), where it converted the pointer, an address (#495); a
// String^ parameter's too; bool(&s) is the pointer's, never nowhere
let parsed(r:String^):i64 { return i64(r) }
let hex(r:Bytes^):u32 { return u32(r, 16) }

let main():int32 {
    var s = String("42")
    var b = Bytes("ff")
    var f = String("2.5")
    println(i64(&s), " ", u8(&s), " ", f64(&f), " ", i64(&s, 8), " ", parsed(&s), " ", hex(&b))
    println(i64(&$"7"), " ", i64(s), " ", u32(b, 16), " ", bool(&s))
    return 0
}
// out: 42 42 2.5 34 42 255
// out: 7 42 255 true
// c: kv_text_int((kv_bytes_cstr(&((*r)).b)), 10, INT64_MIN, INT64_MAX)
