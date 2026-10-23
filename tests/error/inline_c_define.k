// #inline C holds no line of C's preprocessor (#296): a constant is an
// enum's, enum { UNIT = 2 };, or a Kelvin let
#inline C {
static int unit(void) { return 2; }
    #  define UNIT 2
}
let main():int32 {
    return 0
}
// error: '#define' in '#inline C' is C's preprocessor, which Kelvin leaves out (#296): import a header with '#import <x.h> as C' outside it, and write a constant as an enum's or a Kelvin let
