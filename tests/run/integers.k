let printf(fmt:const uint8^, ...):int32;

var answer = 42;                // inferred: i64

let main():int32 {
    var i = -1;                 // inferred: i64
    var big = 0x7fffffffffffffff;
    printf("%d %d %d %d\n", int32(sizeof(int8)), int32(sizeof(int16)), int32(sizeof(int32)), int32(sizeof(int64)));
    printf("%d %d\n", int32(sizeof answer), int32(sizeof i));
    printf("%d\n", big > 0);

    var b:uint8 = 255;
    b = b + 1;                  // C semantics: converts back to u8, wraps
    printf("%d\n", b);

    var w:u128 = 1;
    w = w << 100;
    printf("%d %d\n", int32(sizeof(u128)), int32(w >> 99));

    var s:uint8^ := "bytes";       // string literals are u8 arrays in Kelvin
    printf("%s %c\n", s, s[1]);
    return 0;
}
// out: 1 2 4 8
// out: 8 8
// out: 1
// out: 0
// out: 16 2
// out: bytes y
