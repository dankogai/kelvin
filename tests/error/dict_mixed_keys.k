// every key of a Dictionary literal has one type (#65)
let main():i32 {
    var d = ${"a": 1, 2: 3}
    return 0
}
// error: every key of a Dictionary has one type: this one is i64, the first String
