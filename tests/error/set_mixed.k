// every element of a Set literal has one type (#71)
let main():i32 {
    var x = ${1, "a"}
    return 0
}
// error: every element of a Set has one type: this one is String, the first i64
