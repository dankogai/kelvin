// Iterator<T> (#325), Swift's sequence(state:next:): a state and a function
// of it, which gives each value, a T?, then none; $0 is the state itself,
// which it changes; T is what its first `return v` gives, or written; an
// Iterator is an iterator, walked by for, next(), map, filter, reduce
struct point { x: int64; y: int64 }
let countdown_next(s:int64^):int64? {
    if s^ == 0 { return none }
    s^ -= 1
    return s^ + 1
}
let fibs():Iterator<int64> {
    return Iterator($[0, 1]) {
        let r = $0[0]
        if r > 1000 { return none }
        let next:int64 = $0[0] + $0[1]
        $0[0] = $0[1]
        $0[1] = next
        return r
    }
}
let main():int32 {
    var it = Iterator($[0, 1]) {
        let r = $0[0]
        if r > 100 { return none }
        let next:int64 = $0[0] + $0[1]
        $0[0] = $0[1]
        $0[1] = next
        return r
    }
    for x in it { print(x, ",") }
    println()
    var down = Iterator(3, countdown_next)
    let first = down.next()
    let second = down.next()
    println(first, " ", second)
    for x in down { print(x, ",") }
    println()
    var walk = Iterator<int64>((point){0, 1}) {
        if $0.x > 4 { return none }
        $0.x += $0.y
        return $0.x
    }
    for x in walk {
        if x == 3 { break }
        print(x, ",")
    }
    println(" then ", walk.next())
    println(fibs().filter { $0 % 2 == 0 }, " ", fibs().reduce(0) { $0 + $1 })
    for x in Iterator(10, { (s:int64):int64? in
        if s >= 13 { return none }
        s += 1
        return s
    }) { print(x) }
    println()
    return 0
}
// out: 0,1,1,2,3,5,8,13,21,34,55,89,
// out: some(3) some(2)
// out: 1,
// out: 1,2, then some(4)
// out: [0, 2, 8, 34, 144, 610] 2583
// out: 111213
