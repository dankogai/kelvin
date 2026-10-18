// xs.filter { ... } and xs.reduce(init) { ... } of an Array (#184): a new
// Array of the elements the function says true for, and the value of the
// function of the value so far and each element, from init, of its type;
// owner elements are given as copies, an owner init moves in, and an Array
// an expression gives chains, mapped and freed
let add(a:int64, b:int64):int64 { a + b }
let even(n:int64):bool { n % 2 == 0 }
let main():int32 {
    var xs = $[1, 2, 3, 4, 5]
    var evens = xs.filter { $0 % 2 == 0 }
    var odds = xs.filter { !even($0) }
    var named = xs.filter(even)
    var none = xs.filter { $0 > 9 }
    println(evens, " ", odds, " ", named, " ", none.count, " ", xs)
    var sum = xs.reduce(0) { $0 + $1 }
    var sum2 = xs.reduce(0, add)
    var prod = xs.filter { $0 > 1 }.reduce(1) { $0 * $1 }
    var mean:float64 = xs.reduce(0.0) { $0 + $1 as float64 } / xs.count as float64
    var empty = Array<int64>()
    var nothing = empty.reduce(42) { $0 + $1 }
    println(sum, " ", sum2, " ", prod, " ", mean, " ", nothing)
    var names = $[$"ann", $"bob", $"cy"]
    var longer = names.filter { $0.count > 2 }
    var start = $"<"
    var joined = names.reduce(start) { (s:String, n:String):String in s + n + "," }
    var total = names.map { $0.count as int64 }.reduce(0) { $0 + $1 }
    println(longer, " ", joined, " ", total, " ", names)
    return 0
}
// out: [2, 4] [1, 3, 5] [2, 4] 0 [1, 2, 3, 4, 5]
// out: 15 15 120 3.0 42
// out: ["ann", "bob"] <ann,bob,cy, 8 ["ann", "bob", "cy"]
