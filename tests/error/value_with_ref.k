// error: 'x' is a value (i32): assign it with '=', not ':='
#import <stdlib.h> as C
struct node { value: i32; next: struct node^; };
f(x: i32, p: i32^, n: struct node^)
{
    x := 5;
}
