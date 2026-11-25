// 0 where a pointer goes is C's null (#760), nowhere, in a declaration,
// an assignment, an argument, an element, a member and an Optional;
// any other number there is an error
struct holder { p:int64^, n:int64 }
let null(p:int64^):bool { p.isNull }
let main():int32 {
    var x:int64 = 7
    var p:int64^ := 0
    var q:int64^ := &x
    q := 0
    var ps:[int64^](3) = [0, &x, nowhere]
    var h:holder = {0, 1}
    var o:int64^? = 0
    var a:$[int64^] = $[0x0]
    a += 0
    println(p.isNull, " ", q.isNull, " ", null(0), " ", null(&x))
    println(ps[0].isNull, " ", ps[1]^, " ", ps[2].isNull, " ", h.p.isNull, " ", o.is(some), " ", a.count)
    return 0
}
// out: true true true false
// out: true 7 true true true 2
