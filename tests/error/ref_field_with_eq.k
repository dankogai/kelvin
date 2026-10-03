// error: this target is a reference (struct node^): assign it with ':=', not '='
#import <stdlib.h> as C
struct node { value:i32; next:struct node^; };
f(x:i32, p:i32^, n:struct node^) {
    n^.next = n;
}
