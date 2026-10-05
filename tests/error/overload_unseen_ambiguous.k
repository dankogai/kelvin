// where only C sees that abs gives an int, which two overloads take alike,
// C's _Generic says so (#41)
#import <stdlib.h> as C
twice(n:i64):i64 { n * 2 }
twice(x:f64):f64 { x * 2.0 }
main():i32 {
    println(twice(abs(-3)))
    return 0
}
// error: kv_no_such_overload
