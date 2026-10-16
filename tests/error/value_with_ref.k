// error: 'x' is a value (i32): assign it with '=', not ':='
#import <stdlib.h> as C
struct node { value:int32; next:struct node^; };
let f(var x:int32, p:int32^, n:struct node^) {
    x := 5;
}
