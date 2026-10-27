// header macros that expand to statements must stay usable as statements
#import <stdio.h> as C
#import <assert.h> as C
#import "include/stmt_macros.h" as C

let main():int32 {
    var x:int32 = 1, y:int32 = 2;
    SWAP(x, y);
    LOG(x);
    CHECK(x == 1);
    BLOCK(y);
    static_assert(sizeof(int32) == 4, "i32 is 4 bytes");
    #inline C { __asm__ __volatile__("nop"); }   /* assembly is C's (#399) */
    printf("%d %d\n", x, y);
    return 0;
}
// out: log 2
// out: check failed
// out: block 1
// out: 2 1
