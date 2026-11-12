// a function's name is no place (#534): a variable that holds a function
// is one, set with ':='
let f():i64 { 1 }
let main():int32 {
    f = 1
    return 0
}
// error: the function 'f' is a value, and no place to set: '=' sets a variable, a member, an element or 'p^'
