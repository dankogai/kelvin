// for x in it (#318), Swift's iterator: a value whose var next():T? gives
// each value, then none; the loop calls it until none, and changes it as
// next does, so a var walked in part goes on where it stopped; an
// iterator an expression gives is held in a hidden var
struct countdown { n: int64 }
var countdown.next():int64? {
    if .n == 0 { return none }
    .n -= 1
    return .n + 1
}
let from(n:int64):countdown { return {n} }
let main():int32 {
    for x in from(3) { print(x, ",") }
    println()
    var c:countdown = {5}
    for x in c {
        if x == 3 { break }
        print(x, ",")
    }
    println(" left ", c.n)
    for x in c { print(x, ",") }
    println(" left ", c.n)
    var odd:int64 = 0
    for x:int64 in from(6) {
        if x % 2 == 0 { continue }
        odd += x
    }
    var count = 0
    for _ in from(4) { count += 1 }
    println(odd, " ", count)
    return 0
}
// out: 3,2,1,
// out: 5,4, left 2
// out: 2,1, left 0
// out: 9 4
