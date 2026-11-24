// {} of a T? is none, as a T? declared with no value is (#725): in a
// declaration, a member, an element, an entry, a return and (T?){};
// braces that hold something are the T's initializer, wrapped (#72), and
// {} of a Result is ok of its zero, as it was
struct point { x: int64; y: int64 }
struct holder { o: int64?; name: String? }
var g:int64? = {}
var gp:point? = {}
let nothing():point? { return {} }
let origin():point? { return {0, 0} }
let pick(o:int64?):int64 { o ?? -1 }
let main():int32 {
    var a:int64? = {}
    var p:point? = {}
    var s:String? = {}
    var declared:int64?
    println(a, " ", p, " ", s, " ", declared, " ", g, " ", gp, " ", a == declared)
    var b:int64? = (int64?){}
    var q = (point?){}
    var o = (Optional<int64>){}
    println(b, " ", q, " ", o, " ", (String?){}, " ", q.typename, " ", pick((int64?){}))
    var h:holder = {{}, {}}
    var es:[int64?](2) = [{}, 1]
    var xs:$[point?] = $[{}, {1, 2}]
    var d:${String: int64?} = ${"a": {}}
    var oo:int64?? = {}
    println(h.o, " ", h.name, " ", es[0], " ", es[1], " ", xs, " ", d)
    println(oo, " ", nothing(), " ", origin())
    // what holds something is the value, wrapped
    var w:point? = {1, 2}
    var x = (point?){3, 4}
    var n:int64? = {5}
    println(w, " ", x, " ", n, " ", (int64?){6})
    // a Result has no case with nothing in it: {} is ok of its zero
    var r:Result<int64, int64> = {}
    var t:Result<int64?, int64> = {}
    println(r, " ", (Result<int64, String>){}, " ", t)
    // a case's value is a place, and {} there is the T's zero
    w.some = {}
    println(w)
    return 0
}
// out: none none none none none none true
// out: none none none none point? -1
// out: none none none some(1) [none, some({x: 1, y: 2})] {"a": none}
// out: none none some({x: 0, y: 0})
// out: some({x: 1, y: 2}) some({x: 3, y: 4}) some(5) some(6)
// out: ok(0) ok(0) ok(none)
// out: some({x: 0, y: 0})
