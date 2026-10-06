// Sorting with anonymous functions: a Kelvin sort that takes the order
// as a function, and C's qsort with a comparator
#import <stdlib.h> as C
#import <string.h> as C

// insertion sort: stable, ordered by `before`
let sort(xs:i64^, n:size_t, before:(i64, i64):bool) {
    for i in 1..<n {
        var j:size_t = i
        while j > 0 && before(xs[j], xs[j - 1]) {
            let t:i64 = xs[j]
            xs[j] = xs[j - 1]
            xs[j - 1] = t
            j -= 1
        }
    }
}

let show(xs:i64^, n:size_t) {
    for i in 0..<n {
        print(i == 0 ? "" : " ", xs[i])
    }
    println()
}

let descending(a:i64, b:i64):bool { a > b }

// an anonymous function encloses nothing, so what it shares is global
let target = 5
let distance(x:i64):i64 { x > target ? x - target : target - x }

let main():i32 {
    var xs:[i64](8) = [5, 3, 8, 1, 9, 2, 7, 4]
    sort(xs, 8) { $0 < $1 }                     // the last argument, after the call
    show(xs, 8)
    sort(xs, 8, descending)                     // a named function works too
    show(xs, 8)
    sort(xs, 8) { $0 % 2 < $1 % 2 }             // evens first, in the order they were
    show(xs, 8)
    sort(xs, 8) { distance($[0]) < distance($[1]) }
    show(xs, 8)

    let by_last_digit:(i64, i64):bool := { $0 % 10 < $1 % 10 }
    var ys:[i64](4) = [31, 12, 43, 20]
    sort(ys, 4, by_last_digit)
    show(ys, 4)

    // kelvinc cannot see qsort's comparator type, which is C's, so the
    // function writes its parameters and result
    var names:[u8^](4) = ["kelvin", "celsius", "rankine", "fahrenheit"]
    qsort(names, 4, sizeof(cstr)) { (a:const any^, b:const any^):i32 in
        strcmp((a as const cstr^)^, (b as const cstr^)^)
    }
    for name in names {
        println(name)
    }
    return 0
}
// out: 1 2 3 4 5 7 8 9
// out: 9 8 7 5 4 3 2 1
// out: 8 4 2 9 7 5 3 1
// out: 5 4 7 3 8 2 9 1
// out: 20 31 12 43
// out: celsius
// out: fahrenheit
// out: kelvin
// out: rankine
