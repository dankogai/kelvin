// a fixed array holds its elements, so of itself it holds itself (#659)
struct node { x:i64; kids:[node](2) }
let main():int32 { return 0 }
// error: 'kids' makes node hold itself, and a value that holds itself has no size: hold it by a pointer, node^, or in an Array<node>
