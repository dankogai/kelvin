// a global's value has no self (#621)
let g:i64 = self
let main():int32 {
    println(g)
    return 0
}
// error: 'self' is the value of a method, an attribute or a subscript, and a function has no self
