// xs.map { }.map { } (#183): a map of an Array an expression gives maps it
// and frees it, so that maps chain; a function's Array maps the same way
let make(n:int64):Array<int64> {
    var xs = Array<int64>()
    for i in 1...n { xs += i }
    return xs
}
let main():int32 {
    var xs = $[1, 2, 3]
    var xss = xs.map{ $`${$0}` }.map{ $0 + $"+" }
    var squares = make(4).map { $0 * $0 }
    var lens = xss.map { $0.count as int64 }.map { $0 * 10 }.map { $0 + 1 }
    println(xss, " ", squares, " ", lens, " ", xs)
    return 0
}
// out: ["1+", "2+", "3+"] [1, 4, 9, 16] [21, 21, 21] [1, 2, 3]
