// regressions from the review of #29: where a tag's bare name could also
// be an expression
#import <stdlib.h> as C
#import "include/tag_clash.h" as C
struct node { value:int64; next:node^; };
struct big { a:int64; b:int64; c:int64; next:big^; };
struct gauge;                                // a C struct; the header also has a variable gauge

let node(v:int64):node^ {                      // a constructor named like its struct
    let n := malloc(sizeof(node)) as node^;  // sizeof the struct, never of the function
    n^.value = v;
    n^.next := nullptr;
    return n;
}

let main():int32 {
    let n:node^ := node(4);
    let point:int16 = sizeof(node) as int16;
    let size:int16 = sizeof(point) as int16;    // the variable, in scope from its declarator
    let big:big^ := malloc(sizeof(big^)) as big^;   // C's p = malloc(sizeof *p)
    big^.c = 42;
    println(n^.value, " ", sizeof(node), " ", point, " ", size, " ", big^.c);

    // a struct only declared in Kelvin leaves its name to C in expressions
    var g:gauge = {3};
    println(sizeof(gauge) == sizeof(int32), " ", gauge, " ", g.level);
    free(n);
    free(big);
    return 0;
}
// out: 4 16 16 2 42
// out: true 7 3
