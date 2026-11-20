// two definitions of one function, of the same parameters, are kelvinc's
// error (#646), where they were C's redefinition
let f():i64 { return 1 }
let f():i64 { return 2 }
let main():int32 { println(f()); return 0 }
// error: 'f' is defined already (line 3), with these parameter types: a function is defined once, and its overloads differ in their parameter types
