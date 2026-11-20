// self in a function, which has none, is kelvinc's error, where it was
// C's, use of undeclared identifier 'self' (#621)
let twice(n:i64):i64 { return self * 2 }
let main():int32 {
    println(twice(2))
    return 0
}
// error: 'self' is the value of a method, an attribute or a subscript, and a function has no self
