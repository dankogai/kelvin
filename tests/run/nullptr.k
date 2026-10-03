// no void (#20): any^ is C's void *, nullptr its null, and a reference
// declared without a value is nullptr
#import <stdlib.h> as C
#import <string.h> as C

struct node { value:i32; next:struct node^; };

var g:i32^;                                // a global reference: nullptr

fill(p:any^, n:u64):any^ {
    return memset(p, 7, n);
}

main():i32 {
    var p:any^;                            // means p := nullptr
    var q:i32^;
    var n:struct node^;
    println(p == nullptr, " ", q == nullptr, " ", n == nullptr, " ", g == nullptr);

    var r := nullptr;                       // inferred: any^
    var buf := malloc(16):any^;
    r := buf;
    var bytes:u8^ := fill(r, 16) as u8^;
    println(bytes[0], " ", bytes[15], " ", r != nullptr);
    free(buf);

    var x:i32 = 5;
    q := &x;
    q := nullptr;
    println(q == nullptr, " ", sizeof(any^) == sizeof(i32^));
    return 0;
}
// out: true true true true
// out: 7 7 true
// out: true true
