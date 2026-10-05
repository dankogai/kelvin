// #import is for the top level, also of C headers (#40)
struct p {
    x: f64
    #import <stdio.h> as C
}
main():i32 { return 0 }
// error: #import is for the top level of a file, outside functions, structs and blocks
