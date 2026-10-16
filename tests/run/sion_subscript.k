// s["key"] and s[i] on a SION (#152): copies of a dictionary's value by a
// string or an integer key and of an array's element, nil where there is
// none; setting replaces, adds at the end, or sets an element; s.count
#import <SION>
let main():int32 {
    var s = SION.parse("[\"a\": 1, \"b\": [10, 20], 7: \"seven\"]")
    if s.is(error) { println(s.error); return 1 }
    var b = s["b"]
    var z = s["z"]
    var past = b[5]
    var a1 = s["a"]
    var b1 = b[1]
    var seven = s[7]
    println(a1.integer, " ", b1.integer, " ", seven.string, " ", z.is(nil), " ", past.is(nil), " ", s.count, " ", b.count)
    s["a"] = SION.integer(2)
    s["c"] = SION.string($"new")
    s[8] = SION.boolean(true)
    b[0] = SION.integer(11)
    b[9] = SION.integer(99)        // no such element: nothing changes
    s["b"] = b.copy()
    var t = SION.stringify(&s)
    println(t, " ", s.count)
    var a = SION.array($[SION.integer(1), SION.integer(2)])
    a[1] = SION.nil
    var at = SION.stringify(&a)
    var ax = a["x"]
    println(at, " ", a.count, " ", ax.is(nil))
    var n = SION.integer(5)
    var nx = n["x"]
    var n0 = n[0]
    println(nx.is(nil), " ", n0.is(nil), " ", n.count)
    return 0
}
// out: 1 20 seven true true 3 2
// out: ["a":2,"b":[11,20],7:"seven","c":"new",8:true] 5
// out: [1,nil] 2 true
// out: true true 0
