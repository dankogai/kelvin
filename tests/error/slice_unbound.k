// a slice of an Array an expression gives would never be freed (#68)
let main():i32 {
    var y = $[1, 2][0..<1]
    return 0
}
// error: a slice of an Array that an expression gives, which nothing would free: bind it to a variable first
