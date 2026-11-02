// x.isEmpty (#434): whether a collection has no element, its count 0; an
// iterator and a Sequence, lazy ones too, have no count, and theirs is
// false, even where they would give nothing; a field of the name wins
// out: true true false true false
// out: true false false true false
// out: true false true false
// out: false false false false false false
// out: true false false
// out: true false
// out: ok
struct countdown { n: int64 }
var countdown.next():int64? {
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
struct deck { top: int64 }
let deck.makeIterator():countdown { return {.top} }
let twice(n:int64):int64 { return n * 2 }
struct box { isEmpty: bool }

let fibs():Iterator<int64> {
    return Iterator($[0, 1]) {
        let r = $0[0]
        if r > 10 { return none }
        let next:int64 = $0[0] + $0[1]
        $0[0] = $0[1]
        $0[1] = next
        return r
    }
}

let main():int32 {
    var b:Bytes
    var s:String
    let xs:$[int64] = $[]
    let ys = $[1, 2]
    var d:Dictionary<String, int64>
    let st = ${1, 2}
    let a:[i32] = [1, 2, 3]
    let c:cstr := ""
    let c2:cstr := "x"
    println(b.isEmpty, " ", s.isEmpty, " ", $"a".isEmpty, " ", xs.isEmpty, " ", ys.isEmpty)
    println(d.isEmpty, " ", st.isEmpty, " ", a.isEmpty, " ", c.isEmpty, " ", c2.isEmpty)
    let r = 3..<3
    println(r.isEmpty, " ", (1...1).isEmpty, " ", (5...4).isEmpty, " ", (0...).isEmpty)
    let cd:countdown = {0}                    // gives nothing, yet has no count: false
    let dk:deck = {0}
    let lm = dk.lazy.map(twice)
    let lf:Iterator<int64> = r.lazy.filter { $0 > 0 }
    let none_left:Iterator<int64> = Iterator<int64>(0) { return none }
    println(cd.isEmpty, " ", dk.isEmpty, " ", fibs().isEmpty, " ", lm.isEmpty, " ", lf.isEmpty, " ", none_left.isEmpty)
    let bx:box = {true}
    println(bx.isEmpty, " ", String(12).isEmpty, " ", ys.map { $0 * 2 }.isEmpty)
    var zs:$[int64] = $[]
    let p := &zs
    print(p^.isEmpty, " ")
    zs.append(1)
    println(p^.isEmpty)
    if xs.isEmpty && !ys.isEmpty { println("ok") }
    return 0
}
