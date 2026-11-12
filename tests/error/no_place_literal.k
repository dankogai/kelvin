// a literal is a value and no place (#534)
let main():int32 {
    5 = 2
    return 0
}
// error: a literal is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
