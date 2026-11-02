// FizzBuzz with a String: built with +=, tested with .isEmpty, made of a
// number by String(n), and moved out by return; a closed range, a
// template literal, and a Range mapped to an Array of Strings.
let fizzbuzz(n:i64):String {
    var r = $""
    if n % 3 == 0 { r += "Fizz" }
    if n % 5 == 0 { r += "Buzz" }
    if r.isEmpty { r = String(n) }
    return r
}

let main():i32 {
    for i in 1...15 {
        println(`${i}: ${fizzbuzz(i)}`)
    }
    let all = (1...100).map(fizzbuzz)                // a Range is a Sequence (#373)
    println(all.filter { $0 == $"FizzBuzz" }.count, " FizzBuzz up to 100, the last at ", all.lastIndex($"FizzBuzz")! + 1)
    return 0
}
// out: 1: 1
// out: 2: 2
// out: 3: Fizz
// out: 4: 4
// out: 5: Buzz
// out: 6: Fizz
// out: 7: 7
// out: 8: 8
// out: 9: Fizz
// out: 10: Buzz
// out: 11: 11
// out: 12: Fizz
// out: 13: 13
// out: 14: 14
// out: 15: FizzBuzz
// out: 6 FizzBuzz up to 100, the last at 90
