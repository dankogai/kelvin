// it.lazy.map(f), it.lazy.filter(f) of an Iterator<T> (#327): an
// Iterator<U> whose state is it, moved in, and whose next asks it for each
// value and calls f only as it is asked; one-shot, so a chain writes .lazy
// again, and its own map, filter and reduce are eager
let tens(n:int64):int64 {
    println("tens of ", n)
    return n * 10
}
let naturals():Iterator<int64> {
    return Iterator(0) {
        $0 += 1
        return $0
    }
}
let evens_squared():Iterator<int64> {
    return naturals().lazy.filter({ $0 % 2 == 0 }).lazy.map({ $0 * $0 })
}
let main():int32 {
    var m = Iterator(0) {
        if $0 >= 4 { return none }
        $0 += 1
        return $0
    }.lazy.map(tens)
    println("made")
    for x in m {
        println("got ", x)
        if x == 20 { break }
    }
    for x in evens_squared() {
        if x > 100 { break }
        print(x, ",")
    }
    println()
    var nat = naturals()
    var odd = nat.lazy.filter { $0 % 2 == 1 }
    let a = odd.next()
    let b = odd.next()
    println(a, " ", b)
    var few = Iterator(0) {
        if $0 >= 5 { return none }
        $0 += 1
        return $0
    }
    println(few.lazy.map { $0 * 3 }.reduce(0) { $0 + $1 })
    return 0
}
// out: made
// out: tens of 1
// out: got 10
// out: tens of 2
// out: got 20
// out: 4,16,36,64,100,
// out: some(1) some(3)
// out: 45
