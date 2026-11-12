// i64(b), a converter's call, is a value and no place (#534)
let main():int32 {
    var b = true
    i64(b) = 1
    return 0
}
// error: a conversion to i64 is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
