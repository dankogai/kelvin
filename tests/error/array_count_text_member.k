// text is no count of a member's array (#783), which was C's error in
// both compilers
struct holder { a:[int64]("x") }
let main():int32 { return 0 }
// error: an array's count is an integer, and this is text
