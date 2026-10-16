// #import is for the top level, also of C headers (#40)
struct p {
    x: float64
    #import <stdio.h> as C
}
let main():int32 { return 0 }
// error: #import is for the top level of a file, outside functions, structs and blocks
