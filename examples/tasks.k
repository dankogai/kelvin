// Tasks: async f(x) calls f on a thread of its own and gives a Task<T>
// at once, which await waits for; an Array holds them, awaited by index.
// Four tasks count the primes in four quarters of a range at once, and
// one gives a String, an owner, moved out to the awaiting caller.

let prime(n:i64):bool {
    if n < 2 { return false }
    var d:i64 = 2
    while d * d <= n {
        if n % d == 0 { return false }
        d += 1
    }
    return true
}

let primes(lo:i64, hi:i64):i64 { (lo..<hi).filter(prime).count }

let report(lo:i64, hi:i64):String { $`${primes(lo, hi)} primes in ${lo}..<${hi}` }

let main():i32 {
    let limit:i64 = 400000
    var quarters:$[Task<i64>] = $[]
    for q in 0..<4 {
        quarters += async primes(limit * q / 4, limit * (q + 1) / 4)   // running already
    }
    let last = async report(limit, limit + 1000)
    var total:i64 = 0
    for i in 0..<quarters.count {
        let n = await quarters[i]
        println("quarter ", i + 1, ": ", n)
        total += n
    }
    println(total, " in all, as one call counts them: ", total == primes(0, limit))
    println(await last)
    return 0
}
// out: quarter 1: 9592
// out: quarter 2: 8392
// out: quarter 3: 8013
// out: quarter 4: 7863
// out: 33860 in all, as one call counts them: true
// out: 70 primes in 400000..<401000
