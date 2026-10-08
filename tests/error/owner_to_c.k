// C sees pointers, not owners (#54, O8)
#import <string.h> as C
let main():i32 {
    var a = Bytes("x")
    strlen(a)
    return 0
}
// error: an owner cannot be given to a C function, which could not free it: pass 'a.at' and 'a.count', or 'a.cstr'
