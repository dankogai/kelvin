// error: 'y' is a value (i32): assign it with '=', not ':='
#import <stdlib.h> as C
struct node { value:i32; next:struct node^; };
let f(x:i32, p:i32^, n:struct node^) {
    var y:i32 := 1;
}
