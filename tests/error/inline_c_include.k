// #inline C holds no #include (#296): the header is #import <x.h> as C,
// outside it; the line after a comment is a line's start too
let main():int32 {
    #inline C {
        /* ctype */ #include <ctype.h>
    }
    return 0
}
// error: '#include' in '#inline C' is C's preprocessor, which Kelvin leaves out (#296): import a header with '#import <x.h> as C' outside it, and write a constant as an enum's or a Kelvin let
