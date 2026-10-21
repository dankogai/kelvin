// xs.contains(x), xs.firstIndex(x), xs.lastIndex(x) (#248): whether x is
// there by the elements' ==, and where first or last, an i64?, some(i)
// or none; of a function, anonymous or named, the elements it says true
// for. A String takes text; an Optional none; an owner given is looked
// at, not moved; an Array an expression gives is held and freed
// out: true false some(1) some(3) none
// out: true some(2) some(2) true
// out: true true some(2) some(1) none
// out: some(1) some(3) true
// out: some(1) true 1
// out: 3
// out: some(1) true
// out: b
// out: some(0)
let even(x:int64):bool { return x % 2 == 0 }
let isb(s:String):bool { return s == $"b" }   // a held operand is a bool too
let nums():Array<int64> { return $[5, 6, 7, 6] }
struct pt { x: int64 }

let main():int32 {
    var xs = $[3, 1, 4, 1, 5]
    println(xs.contains(4), " ", xs.contains(9), " ", xs.firstIndex(1), " ", xs.lastIndex(1), " ", xs.firstIndex(9))
    println(xs.contains { $0 > 4 }, " ", xs.firstIndex { $0 > 3 }, " ", xs.lastIndex(even), " ", xs.contains(even))
    var ws = $[$"a", $"b", $"a"]
    let b = $"b"
    println(ws.contains("b"), " ", ws.contains(b), " ", ws.lastIndex($"a"), " ", ws.firstIndex(isb), " ",
            ws.firstIndex { $0 == $"z" })
    println(nums().firstIndex(6), " ", nums().lastIndex(6), " ", nums().contains { $0 == 7 })
    var os:Array<int64?> = $[1, none, 3]
    println(os.firstIndex(none), " ", os.contains(3), " ", xs.firstIndex(1) ?? -1)
    if let some(i) = xs.lastIndex(1) { println(i) }
    var ns = $[$[1], $[2, 3]]
    println(ns.firstIndex($[2, 3]), " ", ns.contains { $0.count == 1 })
    println(b)
    var ps:Array<pt> = $[]
    ps += (pt){2}
    println(ps.firstIndex { $0.x == 2 })
    return 0
}
