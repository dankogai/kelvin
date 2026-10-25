// xs[r] (#377): a slice by a Range value, as by one written, of an Array,
// a String or a Bytes: lo up to hi, past it where closed, to the end
// without one; out of range, the program ends
let make():$[String] { return $[$"a", $"b", $"c"] }
let main():int32 {
    let xs = $[10, 20, 30, 40, 50]
    let s = $"kelvin"
    let b = Bytes([1, 2, 3, 4])
    let r = 1..<3
    let c:Range<uint8> = 1...3
    let e = 2...
    println(xs[r], " ", xs[c], " ", xs[e], " ", xs[(..<2)], " ", s[r], " ", s[e], " ", b[c].count)
    for k in 0..<3 { print(xs[k..<k + 2], " ") }
    println(make()[1...2], " ", xs[3..<3])
    let bad = 4...9
    println(xs[bad])
    return 0
}
// out: [20, 30] [20, 30, 40] [30, 40, 50] [10, 20] el lvin 3
// out: [10, 20] [20, 30] [30, 40] ["b", "c"] []
// exit: 1
// err: kelvin: range 4..<10 is out of range: the Array has 5
