// ':=' sets a reference, a place too (#534)
let main():int32 {
    var x = 1
    x.i64 := 2
    return 0
}
// error: a conversion to i64 is a value, and no place to set: ':=' sets a variable, a member, an element or 'p^'
