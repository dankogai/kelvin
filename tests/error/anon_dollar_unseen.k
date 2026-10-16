// error: kelvinc cannot see this anonymous function's parameters, so '$0' has no type
#import <stdlib.h> as C
let main():int32 {
    var xs:[int32](2) = [2, 1];
    qsort(xs, 2, sizeof(int32)) { $0 }
    return 0;
}
