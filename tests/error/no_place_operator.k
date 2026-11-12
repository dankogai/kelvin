// what an operator gives is a value and no place (#534)
let main():int32 {
    var x = 1
    (x + 1) = 2
    return 0
}
// error: what '+' gives is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
