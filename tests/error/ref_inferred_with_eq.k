// error: 'b' is a reference (i64^): assign it with ':=', not '='
#import <stdlib.h> as C
struct node { value:int32; next:struct node^; };
let f(x:int32, p:int32^, n:struct node^) {
    var b = malloc(8):int64^;
}
