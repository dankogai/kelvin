// a function never changes, so it is a let; a var holds a function value
// (#31, #45)
var twice(n:i64):i64 { n * 2 }
let main():i32 { return 0 }
// error: a function is a let: write 'let twice(...)', or, for a variable holding a function, 'var f:(T):R := g'
