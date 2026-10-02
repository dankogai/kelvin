// error: 'ok' needs a type: write
// bools infer bool (#24, #25), but kelvinc cannot see that a C function
// returns one
#import <ctype.h> as C
main(): i32
{
    t = true;
    b = 1 < 2;
    ok = isdigit(48);
    return 0;
}
