// error: this target is a value (i32): assign it with '=', not ':='
#import <stdlib.h> as C
struct node { value:int32; next:struct node^; };
let f(x:int32, p:int32^, n:struct node^) {
    p^ := 1;
}
