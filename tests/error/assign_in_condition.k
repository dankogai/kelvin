// error: assignment is a statement in Kelvin, not a value
// C: while ((c = getchar()) != EOF)
#import <stdio.h> as C
main(): i32
{
    var c: i32 = 0;
    while (c = getchar()) != EOF {
        putchar(c);
    }
    return 0;
}
