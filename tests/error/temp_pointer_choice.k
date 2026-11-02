// an arm of ?: is not always evaluated, so a pointer into a temporary in
// it is not held for the call around it (#437): bind the owner first
#import <stdio.h> as C
let side():String { return $"s" }
let main(argc:i32, argv:[cstr]):int32 {
    printf("%s\n", argc > 5 ? side().cstr : "no")
    return 0
}
// error: this is a pointer into a String that an expression gives, which is freed once the expression is done: bind it to a variable first
