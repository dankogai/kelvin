// test, search, match and split with a RegExp on a Bytes (#169), the Bytes
// matched byte by byte: a BytesMatch holds the bytes of the whole and of
// each group with their byte offsets, and split gives pieces of bytes;
// each with a function too
#import <RegExp>
let main():int32 {
    var b = Bytes("key=1;name=ab")
    b += 0xFF
    b += ';'
    b += 'x'
    let pair = $/(\w+)=(?<v>[^;]*)/gb
    var ms = b.match(&pair)
    println(ms.count, " ", b.test(&pair), " ", b.search(&pair), " ", pair.test(&b), " ", pair.search(&b))
    for m in ms {
        var v = m["v"]
        var ve = v.escape()
        var ke = m.data[1].escape()
        var whole = m[0]
        println(ke, " ", ve, " ", m.start, "..<", m.end, " ", m.count, " ", m.has(2), " ", m.startOf(2), " ", whole.count)
    }
    let semi = $/;/b
    var parts = b.split(&semi)
    println(parts.count)
    for p in parts { var pe = p.escape(); println("[", pe, "]") }
    b.split(&semi) { var e = $0.escape(); print("<", e, ">") }
    println()
    b.match(&pair) { print($0.start, " ") }
    println()
    let high = $/[\x80-\xFF]+/gb
    var hm = b.match(&high)
    var he = hm[0].data[0].escape()
    println(hm.count, " ", he, " ", hm[0].start, " ", b.search(&high))
    let each = $//b
    var ab = Bytes("ab")
    var chars = ab.split(&each)
    var empty = Bytes()
    var none = empty.split(&semi)
    var first = $/\w/b
    var fm = ab.match(&first)
    println(chars.count, " ", none.count, " ", fm.count, " ", fm[0].end)
    return 0
}
// out: 2 true 0 true 0
// out: key 1 0..<5 3 true 4 5
// out: name ab\xFF 6..<14 3 true 11 8
// out: 3
// out: [key=1]
// out: [name=ab\xFF]
// out: [x]
// out: <key=1><name=ab\xFF><x>
// out: 0 6 
// out: 1 \xFF 13 13
// out: 2 1 1 1
