// a struct's braces whose first value is an Array, {$[1], 2}, are its
// values (#756): $[1] before a comma of the braces is an Array, and
// $[0] with none is the first parameter of an anonymous function, as
// kelvinc reads them, where kc read both as $0
struct box { xs:$[int64], n:int64 }
let apply(n:int64, f:(int64):int64):int64 { f(n) }
let main():int32 {
    var b:box = {$[1], 2}
    var c:box = {.xs = $[3], .n = 4}
    b.xs += 5
    println(b.xs, " ", b.n, " ", c.xs, " ", c.n)
    println(apply(20, { $[0] - 1 }), " ", apply(20, { $0 + 1 }))
    return 0
}
// out: [1, 5] 2 [3] 4
// out: 19 21
