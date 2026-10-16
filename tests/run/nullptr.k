// no void (#20): any^ is C's void *, nullptr its null, and a reference
// declared without a value is nullptr
#import <stdlib.h> as C
#import <string.h> as C

struct node { value:int32; next:struct node^; };

var g:int32^;                                // a global reference: nullptr

let fill(p:any^, n:uint64):any^ {
    return memset(p, 7, n);
}

let main():int32 {
    var p:any^;                            // means p := nullptr
    var q:int32^;
    var n:struct node^;
    println(p == nullptr, " ", q == nullptr, " ", n == nullptr, " ", g == nullptr);

    var r := nullptr;                       // inferred: any^
    var buf := malloc(16):any^;
    r := buf;
    var bytes:uint8^ := fill(r, 16) as uint8^;
    println(bytes[0], " ", bytes[15], " ", r != nullptr);
    free(buf);

    var x:int32 = 5;
    q := &x;
    q := nullptr;
    println(q == nullptr, " ", sizeof(any^) == sizeof(int32^));
    return 0;
}
// out: true true true true
// out: 7 7 true
// out: true true
