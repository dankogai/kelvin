// regressions from the second review of change #14
#import <stdio.h> as C
#import <stdlib.h> as C
#import "include/macros.h" as C

main(): i32
{
    // a converter groups its whole argument, even an unparenthesized macro
    printf("%d %d %d\n", i32(TOTAL), u8(WRAP), i32(TERN));

    // compound literals of typedef types with suffixes and qualifiers
    a: size_t^ := (size_t[2]){1, 2};
    d: div_t^ := (div_t[2]){{1, 2}, {3, 4}};
    c: size_t = (size_t const){3};
    printf("%d %d %d %d\n", i32(a[1]), d[1].quot, i32(c), i32(sizeof (size_t[2]){1, 2}));
    return 0;
}
// out: 4 0 7
// out: 2 3 3 16
