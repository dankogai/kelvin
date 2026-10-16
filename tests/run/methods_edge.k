// regressions from the review of #18
#import <stdio.h> as C
#import <time.h> as C

struct point { x:int32; y:int32; };
let point.sum():int32 { return .x + .y; }          // was a C-static method; static let T.name() is now a function of the type (#111)

let point.fact(n:int64):int64 {                   // recursion needs no prototype
    if n <= 1 {
        return 1;
    }
    return n * .fact(n - 1);
}

let int64.write(f:FILE^):int32 { fputs(.cstr, f); return fputs("\n", f); }   // header type in a signature
let int64.inc():Self { return self + 1; }

struct timespec;                              // a method on a header struct
let timespec.ms():int64 { return .tv_sec * 1000 + .tv_nsec / 1000000; }

let main():int32 {
    var p:struct point = {1, 2};
    println(p.sum(), " ", p.fact(10));
    (42:int64).write(stdout);
    var x:int64 = 0;
    println(x.inc().inc().inc().inc().inc().inc().inc().inc());   // receivers evaluated once
    var t:struct timespec = {2, 500000000};
    println(t.ms());

    // hex floats, properties and methods on literals
    println(0x1.f4p+9, " ", 0x1.cp-3, " ", 0xff.cstr, " ", 1.e5, " ", 2.cstr, " ", (7:int64).inc());
    return 0;
}
// out: 3 3628800
// out: 42
// out: 8
// out: 2500
// out: 1000.0 0.21875 255 100000.0 2 8
