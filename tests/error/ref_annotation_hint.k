// error: 'buffer' would be a value (i64): use '=' for a value, or annotate a reference such as 'i64^'
#import <stdlib.h> as C
main(): i32 { buffer := malloc(8 * 1024):i64; return 0; }
