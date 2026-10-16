// error: declarations are written 'var name:type', as in 'var head:node^'
#import <stdlib.h> as C
struct node { value:int64; next:node^ }
let node(v:int64):node^ {
    let n := malloc(sizeof(node)) as node^
    n^.value = v
    n^.next := nullptr
    return n
}
let main():int32 {
    node *head = node(1)
    return 0
}
