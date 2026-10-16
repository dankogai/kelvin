// Self is the receiver's type, and a plain function has none (#140)
struct point { x: int64; y: int64 }
let same(p:point):Self { return p }
let main():int32 { return 0 }
// error: 'Self' is the type's name inside 'extend T { }' and in a method, an attribute or a subscript of T: here there is no T
