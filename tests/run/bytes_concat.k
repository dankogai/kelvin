// b + c joins bytes into a new Bytes (#188): b a Bytes or text, c a Bytes,
// text or a byte, one a Bytes; a Bytes in a variable is copied and stays,
// one an expression gives is taken, so that a chain frees what it made
let main():int32 {
    var a = Bytes("ab")
    var b = Bytes([0, 0xFF])
    var c = a + b + "cd" + 0x7F + Bytes([1])
    var d = "x" + a
    var e = a + ""
    var n:uint8 = 9
    var f = a + n
    var ce = c.escape()
    var de = d.escape()
    var fe = f.escape()
    println(ce, " ", c.count, " ", de, " ", e == a, " ", fe, " ", a.count, " ", b.count)
    var z = Bytes() + Bytes()
    var g = b.copy()
    g += &a                                    // += still appends in place
    var ge = g.escape()
    println(z.count, " ", ge)
    return 0
}
// out: ab\x00\xFFcd\x7F\x01 8 xab true ab\x09 2 2
// out: 0 \x00\xFFab
