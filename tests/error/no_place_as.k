// x as i64, C's cast, is a value and no place (#534), under += too
let main():int32 {
    var x:i32 = 1
    x as i64 += 2
    return 0
}
// error: a conversion to i64 is a value, and no place to set: '+=' sets a variable, a member, an element or 'p^'
