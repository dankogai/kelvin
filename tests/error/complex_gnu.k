// GNU C's __complex__ names <math>'s c64 and c32 (#404)
let main():i32 {
    var z:__complex__ f64
    return 0
}
// error: '__complex__' is a C compiler keyword; use c64 or c32 of #import <math> (#404)
