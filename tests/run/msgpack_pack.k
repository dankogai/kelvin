// MsgPack.pack (#153): each value in its smallest form, as the bytes the
// format gives, in hex
#import <MsgPack>
#import <stdio.h> as C
let hex(b:const Bytes^):() {
    for c in b^ { printf("%02x", c) }
    println()
}
let show(text:cstr):() {
    var s = SION.parse(text)
    if s.is(error) { println(s.error); return }
    var p = MsgPack.pack(&s)
    hex(&p)
}
let main():int32 {
    show("[nil, true, false]")
    show("[0, 127, -1, -32, -33, 128, 255, 256, -129, 65535, -32769, 2147483647, 2147483648, -2147483649]")
    show("1.5")
    show("[\"\", \"a\", \"kelvin\", \"ふ\"]")
    show("\"0123456789012345678901234567890123\"")
    show(".Data(\"AQID\")")
    show(".Data(\"\")")
    show(".Date(0x1p+30)")
    show(".Date(1.5)")
    show(".Date(-1.0)")
    show(".Ext(\"1NTU\")")
    show("[]")
    show("[:]")
    show("[1, [2, 3]]")
    show("[\"a\": 1, 2: \"b\"]")
    show("[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]")
    return 0
}
// out: 93c0c3c2
// out: 9e007fffe0d0dfd10080d100ffd10100d1ff7fd20000ffffd2ffff7fffd27fffffffd30000000080000000d3ffffffff7fffffff
// out: cb3ff8000000000000
// out: 94a0a161a66b656c76696ea3e381b5
// out: d92230313233343536373839303132333435363738393031323334353637383930313233
// out: c403010203
// out: c400
// out: d7ff0000000040000000
// out: d7ff7735940000000001
// out: c70cff00000000ffffffffffffffff
// out: d4d4d4
// out: 90
// out: 80
// out: 9201920203
// out: 82a1610102a162
// out: dc0010000102030405060708090a0b0c0d0e0f
