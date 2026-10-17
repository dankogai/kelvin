// replace with a RegExp on a Bytes (#170): the replacement a Bytes borrowed
// or text, with $&, $1, $<name>, $`, $' and $$ over bytes, or a function of
// each BytesMatch giving the Bytes to put; all matches with g, the first
// alone without, an empty match moving on by a byte
#import <RegExp>
let main():int32 {
    var b = Bytes("key=1;name=ab")
    b += 0xFF
    let pair = $/(\w+)=(?<v>[^;]*)/gb
    var with = Bytes("<$<v>>")
    with += 0
    var r1 = b.replace(&pair, &with)
    var r2 = b.replace(&pair, "$1:$&")
    var r3 = pair.replace(&b, "[$$]")
    var r4 = b.replace(&pair) { var k = $0[1]; k += '!'; return k }
    var e1 = r1.escape()
    var e2 = r2.escape()
    var e3 = r3.escape()
    var e4 = r4.escape()
    println(e1)
    println(e2)
    println(e3)
    println(e4)
    let empty = $/x*/gb
    let first = $/\w+/b
    var ab = Bytes("ab")
    var r5 = ab.replace(&empty, "-")
    var r6 = b.replace(&first, "$`|$'")
    var e5 = r5.escape()
    var e6 = r6.escape()
    println(e5, " ", e6, " ", r6.count)
    return 0
}
// out: <1>\x00;<ab\xFF>\x00
// out: key:key=1;name:name=ab\xFF
// out: [$];[$]
// out: key!;name!
// out: -a-b- |=1;name=ab\xFF=1;name=ab\xFF 23
