// a value only C sees, as a C function's result, has no type kelvinc can
// infer (#47): write it
#import <string.h> as C
let main():i32 {
    var n = strlen("abc")
    return 0
}
// error: 'n' needs a type: write 'n:T = ...'
