// Sequences: a struct with a var method next() is an iterator, which for
// walks and map, filter and reduce read to its none; prefix stops one
// that never ends, and a Range with no end, 2..., is filtered lazily.

struct collatz { n: i64 }
var collatz.next():i64? {                            // each value, then none
    if .n == 0 { return none }
    let v = .n
    .n = v == 1 ? 0 : v % 2 == 0 ? v / 2 : 3 * v + 1
    return v
}
let hailstones(n:i64):collatz { return {n} }

struct fibonacci { a: i64; b: i64 }
var fibonacci.next():i64? {                          // never none
    let v = .a
    .a = .b
    .b += v
    return v
}

let prime(n:i64):bool {
    if n < 2 { return false }
    for d in 2... {
        if d * d > n { break }
        if n % d == 0 { return false }
    }
    return true
}

let main():i32 {
    println(hailstones(6).map { $0 })
    let steps = (1...30).map { hailstones($0).reduce(0) { n, _ in n + 1 } }
    let most = steps.reduce(0) { $0 > $1 ? $0 : $1 }
    println("from ", steps.firstIndex(most)! + 1, ", ", most, " numbers, up to ", hailstones(27).reduce(0) { $0 > $1 ? $0 : $1 })

    let fib:fibonacci = {0, 1}
    println(fib.prefix(12).map { $0 })
    println(fib.prefix { $0 < 1000 }.filter { $0 % 2 == 0 })

    println((2...).lazy.filter(prime).prefix(10).map { $0 })
    println((2...).lazy.filter(prime).lazy.map { $0 * $0 }.prefix { $0 < 200 }.map { $0 })
    return 0
}
// out: [6, 3, 10, 5, 16, 8, 4, 2, 1]
// out: from 27, 112 numbers, up to 9232
// out: [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
// out: [0, 2, 8, 34, 144, 610]
// out: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
// out: [4, 9, 25, 49, 121, 169]
