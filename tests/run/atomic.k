// atomic T is C's _Atomic (#642): eight Tasks add 100000 each to an atomic
// i64 and none of their additions is lost, x += 1 being C's atomic
// operation; a bool too
var hits:atomic i64 = 0
var done:atomic bool = false
let work(n:i64):i64 {
    for _ in 0..<n {
        hits += 1
    }
    done = true
    return n
}
let main():int32 {
    var ts:$[Task<i64>] = $[]
    for _ in 0..<8 { ts += async work(100000) }
    var total:i64 = 0
    for i in 0..<8 { total += await ts[i] }
    println(hits, " ", total, " ", done, " ", hits.typename)
    return 0
}
// out: 800000 800000 true i64
