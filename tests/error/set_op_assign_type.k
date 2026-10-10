// |= takes another Set of the same type, in a variable (#73)
let main():i32 {
    var s = ${1, 2}
    s |= ${3}
    return 0
}
// error: '|=' takes another Set<i64>, in a variable
