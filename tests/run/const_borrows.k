// &x of a let is a const borrow (#273), of an owner too: it goes where a
// const T^ goes, as const $[T]^, const Dictionary<K, V>^, const String^
// or const Set<T>^, through which everything reads and nothing changes;
// &x of a var goes there too
// out: 10 5 5
// out: [1, 2, 3] true some(2) [2, 4, 6] [2, 3] 6
// out: [1, 2, 3] [3, 2, 1] true [2, 3]
// out: {"a": 1, "b": 2} some(1) true 0 2 3 some("b")
// out: true false
// out: [4, 5] false none [8, 10] [4, 5] 9
// out: [4, 5] [5, 4] false [5]
let total(xs:const $[int64]^):int64 {
    var t = 0
    for x in xs^ { t += x }
    return t + xs^[0] + xs^.count as int64
}
let show(xs:const Array<int64>^) {
    println(xs^, " ", xs^.contains(2), " ", xs^.firstIndex(3), " ", xs^.map { $0 * 2 }, " ", xs^.filter { $0 > 1 }, " ", xs^.reduce(0) { $0 + $1 })
    println(xs^.sorted(), " ", xs^.reversed(), " ", xs^ == $[1, 2, 3], " ", xs^[1...])
}
let look(d:const Dictionary<String, int64>^) {
    var s = 0
    for k, v in d^ { s += v }
    println(d^, " ", d^["a"], " ", d^.has("b"), " ", d^.get("z", 0), " ", d^.count, " ", s, " ", d^.firstKey(2))
}
let size(s:const String^):int64 { return s^.count as int64 }
let has3(s:const Set<int64>^):bool { return s^.has(3) }

let main():int32 {
    let xs = $[1, 2, 3]
    let d = ${"a": 1, "b": 2}
    let s = $"héllo"
    let set:Set<int64> = {1, 3}
    var other:Set<int64> = {2}
    println(total(&xs), " ", size(&s), " ", s.count)
    show(&xs)
    look(&d)
    println(has3(&set), " ", has3(&other))
    var ys = $[4, 5]
    show(&ys)
    return 0
}
