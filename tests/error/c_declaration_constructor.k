// error: declarations are written 'var name:type', as in 'var head:node^'
#import <stdlib.h> as C
struct node { value:i64; next:node^ }
let node(v:i64):node^ {
    let n := malloc(sizeof(node)) as node^
    n^.value = v
    n^.next := nullptr
    return n
}
let main():i32 {
    node *head = node(1)
    return 0
}
