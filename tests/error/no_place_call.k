// what a function gives is a value and no place (#534)
let f():i64 { 1 }
let main():int32 {
    f() = 2
    return 0
}
// error: what a function gives is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
