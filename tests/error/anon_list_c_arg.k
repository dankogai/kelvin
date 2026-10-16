// error: a list is not a value here: write a compound literal, as in '(i32[3]){1, 2, 3}'
#import <string.h> as C
let main():int32 {
    var buf:[uint8](4);
    memcpy(buf, {'a', 'b', 'c'}, 3);
    return 0;
}
