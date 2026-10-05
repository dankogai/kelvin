// an unfinished value at the end of an imported file is an error there (#40)
#import "lib/unfinished_expr.k"
main():i32 { return 0 }
// error: lib/unfinished_expr.k:4:1: error: expected an expression, found the end of
