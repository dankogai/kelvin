// Bytes(&s) is a copy of a String's bytes (#291), as bytes.md has it:
// of a var, a let, an empty one, a borrowed parameter, a String an
// expression gives; the String stays. It was garbage: KV_BYTES_OF took a
// String's pointer for text
let f(p:const String^):Bytes { Bytes(p) }
let mk():String { $"made" }
let main():int32 {
    var v = $"abc"
    let u = $"héllo"
    let e = $""
    var b = Bytes(&v)
    b += 0x21
    println(b, " ", Bytes(&u), " ", Bytes(&u).count, " ", Bytes(&e).count, " ", f(&v), " ", Bytes(&$"tmp"), " ", Bytes(&mk()), " ", v)
    println(Bytes(&u) == Bytes("héllo"), " ", Bytes(&u).string() == u)
    return 0
}
// out: abc! héllo 6 0 abc tmp made abc
// out: true true
