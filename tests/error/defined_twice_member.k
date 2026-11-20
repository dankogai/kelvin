// a member written twice in a struct (#646), C's duplicate member
struct p { x:i64; x:i64 }
let main():int32 { return 0 }
// error: 'x' is a member of struct p already (line 2): name this one otherwise
