// a C library in ./modules: C finds its header there, and -lanswer in
// KELVIN_CFLAGS, which go after the program, finds libanswer.a (#46)
#import <answer.h> as C
let main():i32 {
    println(answer())
    return 0
}
// cflags: -lanswer
// out: 42
