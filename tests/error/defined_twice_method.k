// two definitions of one method, of the same parameters (#646)
struct p { x:i64 }
let p.g():i64 { return 1 }
let p.g():i64 { return 2 }
let main():int32 { let q:p = {1}; println(q.g()); return 0 }
// error: 'p.g' is defined already (line 3), with these parameter types: a function is defined once, and its overloads differ in their parameter types
