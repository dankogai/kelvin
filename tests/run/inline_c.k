// #inline C { ... } (#197): C of the program's own, written into the
// generated C where it stands. Its braces are counted as C counts them,
// outside strings, characters and comments; it holds no preprocessor
// line (#296), so a header is imported before it and a constant is C's
// own; Kelvin calls its functions and uses its types as a header's, and
// it calls a Kelvin function written before it
#import <ctype.h> as C
let twice(x:int32):int32 { x * 2 }

#inline C {
static const char CLOSE = '}';         /* a brace in a character */
static const char *const banner = "{ not a block }";
typedef struct { int x, y; } cpoint;
int cplus(int a, int b) {
    if (a > b) { return a + b; }       // } in a comment
    return twice(a) + b;               /* C calls Kelvin */
}
static cpoint corigin(void) { cpoint p = {3, 4}; return p; }
}

#inline C { static int cupper(int c) { return toupper(c); } }

let main():int32 {
    println(cplus(1, 2), " ", cplus(5, 1))
    println(banner, " ", CLOSE == 125)
    let p:cpoint = corigin()
    println(p.x, " ", p.y, " ", cupper(97))
    return 0
}
// out: 4 6
// out: { not a block } true
// out: 3 4 65
// c: static const char *const banner = "{ not a block }";
// c: static int cupper(int c) { return toupper(c); }
