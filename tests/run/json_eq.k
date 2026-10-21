// a JSON and a SION compare with == (#247), since an Array in a case
// has ==: an array's elements in order, a JSON object's members in any
// order, a SION dictionary's entries in order, as SION.same
// out: true false true
// out: true false true
// out: true false
#import <JSON>
#import <SION>
let main():int32 {
    var a = JSON.parse("[1, {\"a\": [true, null], \"b\": \"x\"}]")
    var b = JSON.parse("[1, {\"b\": \"x\", \"a\": [true, null]}]")
    var c = JSON.parse("[1, {\"a\": [false], \"b\": \"x\"}]")
    println(a == b, " ", a == c, " ", a != c)
    var s = SION.parse("[\"a\": [1, 2.5], 7: \"seven\"]")
    var t = SION.parse("[\"a\": [1, 2.5], 7: \"seven\"]")
    var u = SION.parse("[7: \"seven\", \"a\": [1, 2.5]]")
    println(s == t, " ", s == u, " ", (s == u) == SION.same(&s, &u))
    var o:Array<int64>? = $[1, 2]
    var p:Array<int64>? = $[1, 2]
    println(o == p, " ", o == none)
    return 0
}
