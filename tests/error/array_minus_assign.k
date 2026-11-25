// an Array has += alone (#763), as a Set
let main():int32 {
    var xs:$[int64] = $[1, 2]
    xs -= 1
    return 0
}
// error: an Array has no '-=': remove elements with xs.remove(i, n)
