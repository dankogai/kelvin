// no void (#20): any^ is C's void *, nowhere its null, and a reference
// declared without a value is nowhere
#import <stdlib.h> as C
#import <string.h> as C

struct node { value:int32; next:struct node^; };

var g:int32^;                                // a global reference: nowhere

let fill(p:any^, n:uint64):any^ {
    return memset(p, 7, n);
}

let main():int32 {
    var p:any^;                            // means p := nowhere
    var q:int32^;
    var n:struct node^;
    println(p == nowhere, " ", q == nowhere, " ", n == nowhere, " ", g == nowhere);

    var r := nowhere;                       // inferred: any^
    var buf := malloc(16):any^;
    r := buf;
    var bytes:uint8^ := fill(r, 16) as uint8^;
    println(bytes[0], " ", bytes[15], " ", r != nowhere);
    free(buf);

    var x:int32 = 5;
    q := &x;
    q := nowhere;
    println(q == nowhere, " ", sizeof(any^) == sizeof(int32^));
    return 0;
}
// out: true true true true
// out: 7 7 true
// out: true true
