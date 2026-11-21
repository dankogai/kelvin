// two structs that hold each other by value (#659): the first written says it
struct a { x:i64; b:b }
struct b { y:i64; a:a }
let main():int32 { return 0 }
// error: 'b' makes a hold itself, and a value that holds itself has no size: hold it by a pointer, a^, or in an Array<a>
