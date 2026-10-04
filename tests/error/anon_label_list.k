// error: a list is not a value here: write a compound literal
#import <stdio.h> as C
main():i32 {
    printf("%p\n", {x: 1})
    return 0
}
