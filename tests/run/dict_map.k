// d.map, d.filter and d.reduce of a Dictionary (#238), of its values alone,
// as an Array's of its elements: a sparse Array. map keeps each key with
// the function's value, of any type; filter keeps the entries whose value
// it says true for; reduce folds the values in the order added. A value
// that owns is given as a copy, which the function owns; a Dictionary an
// expression gives is freed after
// out: {"ann": 62, "bob": 84, "cy": 14} {"ann": "31", "bob": "42", "cy": "7"} {"ann": 31, "bob": 42} 80
// out: {3: "three"} {1: 3, 2: 3, 3: 5} onetwothree
// out: {"ann": 32, "bob": 43, "cy": 8} {"bob": 42} 80
// out: {} {} 5
let ages():Dictionary<String, int64> { return ${"ann": 31, "bob": 42, "cy": 7} }
let even(n:int64):bool { return n % 2 == 0 }

let main():int32 {
    var a = ${"ann": 31, "bob": 42, "cy": 7}
    var doubled = a.map { v in v * 2 }
    var text = a.map { v in String(v) }
    var big = a.filter { v in v > 10 }
    let sum = a.reduce(0) { acc, v in acc + v }
    println(doubled, " ", text, " ", big, " ", sum)
    var names = ${1: $"one", 2: $"two", 3: $"three"}
    var wordy = names.filter { s in s.count > 3 }
    var sizes = names.map { s in s.count }
    let joined = names.reduce($"") { acc, s in acc + s }
    println(wordy, " ", sizes, " ", joined)
    println(ages().map { $0 + 1 }, " ", ages().filter(even), " ", ages().reduce(0) { $0 + $1 })
    var empty:Dictionary<String, int64> = ${:}
    println(empty.map { v in v }, " ", empty.filter { v in true }, " ", empty.reduce(5) { acc, v in acc + v })
    return 0
}
