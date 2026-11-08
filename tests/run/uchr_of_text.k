// uchr(x) of a String or a Bytes, or one by reference, is the first
// codepoint of its text, as of text; U+FFFD of empty text (#494)
let first(s:String^):uchr { return uchr(s) }

let main():int32 {
    var s = String("éa")
    var b = Bytes("Zq")
    var e = String()
    println(uchr(s), " ", uchr(&s), " ", uchr(b), " ", uchr(&b), " ", first(&s))
    println(uchr($"日本"), " ", uchr(Bytes("Q")), " ", uchr(e).utf32.hex, " ", uchr(s) == 0xE9)
    let n:i32 = 0x41
    println(uchr(n), " ", uchr(n + 1), " ", uchr(sizeof(n) + 0x30))
    return 0
}
// out: é é Z Z é
// out: 日 Q 0xfffd true
// out: A B 4
// c: (KV_UCHR_OF(kv_bytes_cstr(&(s).b)))
