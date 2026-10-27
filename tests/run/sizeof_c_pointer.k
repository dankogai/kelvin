// the size of a pointer to a C header's type (#400): sizeof(any^), every
// object pointer's, or x.size of one; sizeof(FILE^) is left out, as
// kelvinc reads no header and takes FILE^ for a dereference, as stdout^ is
#import <stdio.h> as C
let main():i32 {
    let f:FILE^ := stdout
    println(sizeof(any^) == f.size, " ", sizeof(any^) == sizeof(i64^), " ", sizeof(FILE) == sizeof(stdout^))
    return 0
}
// out: true true true
