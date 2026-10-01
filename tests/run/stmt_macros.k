// header macros that expand to statements must stay usable as statements
#import <stdio.h> as C
#import <assert.h> as C
#import "include/stmt_macros.h" as C

main(): i32
{
    var x: i32 = 1, y: i32 = 2;
    SWAP(x, y);
    LOG(x);
    CHECK(x == 1);
    BLOCK(y);
    static_assert(sizeof(i32) == 4, "i32 is 4 bytes");
    __asm__("nop");
    printf("%d %d\n", x, y);
    return 0;
}
// out: log 2
// out: check failed
// out: block 1
// out: 2 1
