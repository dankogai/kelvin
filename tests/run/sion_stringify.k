// SION.stringify (#152): compact and indented text, a double as C's %a,
// a date as .Date(%a), data and an ext in base64, Swift's escapes, and
// what it writes reads back the same
#import <SION>
let main():int32 {
    var s = SION.parse("[\"k\": [1, 2.5, \"x\\ty\\u{1}\\0\", nil, true, .Date(1.5), .Data(\"AQID\"), .Ext(\"1NTU\"), [], [:], [0: 1]], 3: -0x10]")
    if s.is(error) { println(s.error); return 1 }
    var flat = SION.stringify(&s)
    println(flat)
    var two = SION.stringify(&s, 2)
    println(two)
    var dot = SION.stringify(&s, ".")
    println(dot)
    var back = SION.parse(&flat)
    var again = SION.parse(&two)
    println(SION.same(&s, &back), " ", SION.same(&s, &again), " ", SION.same(&back, &again))
    var n = SION.parse("[nan, inf, -inf, 0.1, 1e300, -0.0]")
    var ntext = SION.stringify(&n)
    var nback = SION.parse(&ntext)
    var first = nback[0]
    var tenth = nback[3]
    var big = nback[4]
    println(ntext, " ", first.number != first.number, " ", tenth.number == 0.1, " ", big.number == 1e300)
    var e = SION.error($"why")
    var etext = SION.stringify(&e)
    println(etext)
    return 0
}
// out: ["k":[1,0x1.4p+1,"x\ty\u{1}\0",nil,true,.Date(0x1.8p+0),.Data("AQID"),.Ext("1NTU"),[],[:],[0:1]],3:-16]
// out: [
// out:   "k" : [
// out:     1,
// out:     0x1.4p+1,
// out:     "x\ty\u{1}\0",
// out:     nil,
// out:     true,
// out:     .Date(0x1.8p+0),
// out:     .Data("AQID"),
// out:     .Ext("1NTU"),
// out:     [],
// out:     [:],
// out:     [
// out:       0 : 1
// out:     ]
// out:   ],
// out:   3 : -16
// out: ]
// out: [
// out: ."k" : [
// out: ..1,
// out: ..0x1.4p+1,
// out: .."x\ty\u{1}\0",
// out: ..nil,
// out: ..true,
// out: ...Date(0x1.8p+0),
// out: ...Data("AQID"),
// out: ...Ext("1NTU"),
// out: ..[],
// out: ..[:],
// out: ..[
// out: ...0 : 1
// out: ..]
// out: .],
// out: .3 : -16
// out: ]
// out: true true true
// out: [nan,inf,-inf,0x1.999999999999ap-4,0x1.7e43c8800759cp+996,-0x0p+0] true true true
// out: "why"
