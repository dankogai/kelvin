// a value only C sees, as malloc's result, has no type kelvinc can infer
#import <stdlib.h> as C
// error: 'p' needs a type: write 'p:T = ...' (or 'p:T := ...' for a reference)
let main():i32 { var p := malloc(4); return 0; }
