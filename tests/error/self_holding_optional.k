// an Optional holds its value, so a struct of a T? of itself holds itself (#659)
struct node { x:i64; next:node? }
let main():int32 { return 0 }
// error: 'next' makes node hold itself, and a value that holds itself has no size: hold it by a pointer, node^, or in an Array<node>
