// an overloaded name as a value needs the type that says which (#41)
#import <stdio.h> as C
twice(n:i64):i64 { n * 2 }
twice(x:f64):f64 { x * 2.0 }
main():i32 {
    printf("%p\n", twice as any^)
    return 0
}
// error: 'twice' names 2 functions: say which by its type, as in 'let f:(T):R := twice'
