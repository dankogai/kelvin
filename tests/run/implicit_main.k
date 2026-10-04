// main keeps C's rule that its end returns 0, so its one expression is
// a statement, and printf's count is not its exit status (#35)
#import <stdio.h> as C
main():i32 {
    printf("hi\n")
}
// out: hi
