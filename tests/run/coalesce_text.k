// v ?? "unset" of a cstr? (#72): a string literal, or text of another
// spelling, on the right is cast to the value's type, since C's ?: of a
// const uint8_t * and a char * is no text (found by examples/results.k)
#import <stdlib.h> as C
let env(name:cstr):cstr? {
    let v:cstr := getenv(name)
    if v.isNull { return none }
    return v
}
let main():int32 {
    var unset = env("KELVIN_NO_SUCH_VARIABLE")
    println(unset ?? "unset")
    let d:cstr := "dflt"
    println(unset ?? d)
    var n:int64 = 42
    println(unset ?? n.cstr, " ", unset ?? n.hex)
    var p:uint8^? = none
    println(p ?? "bytes")
    var r:Result<cstr, int32> = err(1)
    println(r ?? "failed")
    var t := unset ?? "typed"
    println(t.typename, " ", t)
    var s:cstr? = "set"
    println(s ?? "unset", " ", s ?? d)
    var m:uint8^? = none
    println(m ?? d)
    return 0
}
// out: unset
// out: dflt
// out: 42 +0x2a
// out: bytes
// out: failed
// out: cstr typed
// out: set set
// out: dflt
// c: (const uint8_t *)"unset"
// c: (uint8_t *)"bytes"
