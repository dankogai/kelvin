// The sieve of Eratosthenes: a bool array, nested ranges, and continue.
enum { LIMIT = 100 }

let main():i32 {
    var composite:[bool](LIMIT + 1) = [false]
    var count = 0
    for n in 2...LIMIT {
        if composite[n] {
            continue
        }
        print(n, " ")
        count += 1
        for k in n...LIMIT / n {     // empty once n * n > LIMIT
            composite[n * k] = true
        }
    }
    println()
    println(count, " primes up to ", LIMIT)
    return 0
}
// out: 2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97 
// out: 25 primes up to 100
