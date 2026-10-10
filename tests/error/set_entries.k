// a Set holds elements, a Dictionary entries (#71)
let main():i32 {
    var x = ${"a", "b": 1}
    return 0
}
// error: a Set holds elements, not entries: ${a, b, c}; a Dictionary's are ${k: v}
