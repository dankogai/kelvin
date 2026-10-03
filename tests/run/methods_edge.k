// regressions from the review of #18
#import <stdio.h> as C
#import <time.h> as C

struct point { x:i32; y:i32; };
static point.sum():i32 { return self.x + self.y; }   // a static method

point.fact(n:i64):i64 {                       // recursion needs no prototype
    if n <= 1 {
        return 1;
    }
    return n * self.fact(n - 1);
}

i64.write(f:FILE^):i32 { fputs(self.cstr, f); return fputs("\n", f); }   // header type in a signature
i64.inc():i64 { return self + 1; }

struct timespec;                              // a method on a header struct
timespec.ms():i64 { return self.tv_sec * 1000 + self.tv_nsec / 1000000; }

main():i32 {
    var p:struct point = {1, 2};
    println(p.sum(), " ", p.fact(10));
    (42:i64).write(stdout);
    var x:i64 = 0;
    println(x.inc().inc().inc().inc().inc().inc().inc().inc());   // receivers evaluated once
    var t:struct timespec = {2, 500000000};
    println(t.ms());

    // hex floats, properties and methods on literals
    println(0x1.f4p+9, " ", 0x1.cp-3, " ", 0xff.cstr, " ", 1.e5, " ", 2.cstr, " ", (7:i64).inc());
    return 0;
}
// out: 3 3628800
// out: 42
// out: 8
// out: 2500
// out: 1e+03 0.21875 255 1e+05 2 8
