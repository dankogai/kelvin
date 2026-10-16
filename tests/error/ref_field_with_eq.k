// error: this target is a reference (struct node^): assign it with ':=', not '='
#import <stdlib.h> as C
struct node { value:int32; next:struct node^; };
let f(x:int32, p:int32^, n:struct node^) {
    n^.next = n;
}
