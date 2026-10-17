// Bytes([...]) (#172): a Bytes of the bytes written out, each a byte's
// value, a character constant or a number 0 to 255; Bytes([]) is empty
let main():int32 {
    var b = Bytes(['\x00', '\x01', '\x02', '\x03'])
    var c = Bytes([0, 1, 255, 'A', 0x7F])
    var d = Bytes([])
    var e = b.escape()
    var f = c.escape()
    println(e, " ", b.count, " ", f, " ", c.count, " ", d.count, " ", b[3], " ", c[2])
    var n:int64 = 7
    var g = Bytes([n as uint8, 'z'])
    g += Bytes([9, 8])
    var h = g.escape()
    var same = Bytes([7, 'z', 9, 8])
    println(h, " ", g.count, " ", g == same)
    return 0
}
// out: \x00\x01\x02\x03 4 \x00\x01\xFFA\x7F 5 0 3 255
// out: \x07z\x09\x08 4 true
