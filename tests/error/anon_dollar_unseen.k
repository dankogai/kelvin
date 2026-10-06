// error: kelvinc cannot see this anonymous function's parameters, so '$0' has no type
#import <stdlib.h> as C
let main():i32 {
    var xs:[i32](2) = [2, 1];
    qsort(xs, 2, sizeof(i32)) { $0 }
    return 0;
}
