// xs[r] slices an Array, a String or a Bytes by a Range value (#377), and a Dictionary is none
let main():int32 {
    let r = 0..<1
    let d = ${"a": 1}
    let x = d[r]
    return 0
}
// error: a slice [lo..<hi] is of an Array, a String or a Bytes, and this is Dictionary<String, i64>
