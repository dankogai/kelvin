// a struct that holds itself by value has no size: kelvinc's error (#659),
// where kelvinc ran out of stack and ended with a segmentation fault
struct node { x:i64; next:node }
let main():int32 { return 0 }
// error: 'next' makes node hold itself, and a value that holds itself has no size: hold it by a pointer, node^, or in an Array<node>
