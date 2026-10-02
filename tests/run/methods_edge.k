// regressions from the review of #18
#import <stdio.h> as C
#import <stdlib.h> as C
#import <time.h> as C

struct buf { n: i32; a: i32[]; };            // flexible array member
struct point { x: i32; y: i32; };
static point.toString(): String { return self.x.fmt("P%d"); }   // static override

point.fact(n: i64): i64                       // recursion needs no prototype
{
    if (n <= 1)
        return 1;
    return n * self.fact(n - 1);
}

String.write(f: FILE^): i32 { return fputs(self.bytes as const u8^, f); }   // header type in a signature
i64.inc(): i64 { return self + 1; }

struct timespec;                              // a header struct with a user toString
timespec.toString(): String { return (self.tv_sec * 1000 + self.tv_nsec / 1000000).fmt("%dms"); }
struct event { id: i32; at: struct timespec; };

struct named { si: i8^; };

main(): i32
{
    // fmt in the value's own width
    a: i32 = -1;
    b: i8 = -1;
    c: i16 = -2;
    println(a.fmt("%x"), " ", b.fmt("%x"), " ", a.fmt("%u"), " ", c.fmt("%o"));
    m: i128 = -1;
    big: u128 = 18446744073709551615;
    big = big + 1;
    println(m.fmt("%x"), " ", big.fmt("%#x"), " ", big.fmt("%025d"), " ", big.fmt("%.3d"));
    println(65.fmt("%05c"), "|", (5:u8).fmt("%+d"), "|", true.fmt("%.1f"), "|", 5.fmt("%99999d"));

    p: struct point = {1, 2};
    println(p.toString(), " ", p.fact(10));
    q: struct buf^ := malloc(sizeof(struct buf) + 4 * sizeof(i32));
    q^.n = 3;
    println(q^.toString());
    free(q);
    s: String = 42.toString();
    s.write(stdout);
    println();
    x: i64 = 0;
    println(x.inc().inc().inc().inc().inc().inc().inc().inc());   // receivers evaluated once
    e: struct event = {1, {2, 500000000}};
    println(e.toString());

    // hex floats, method calls on literals, complex numbers, i8^ strings
    println(0x1.f4p+9, " ", 0x1.cp-3, " ", 0xff.fmt("%#x"), " ", 1.e5, " ", 2.toString());
    z: f64 _Complex = 1.0;
    n: struct named = {"hi" as i8^};
    println(z.toString(), " ", n.si.toString(), " ", n.toString());
    return 0;
}
// out: ffffffff ff 4294967295 177776
// out: ffffffffffffffffffffffffffffffff 0x10000000000000000 0000018446744073709551616 18446744073709551616
// out:     A|+5|1.0|<invalid format>
// out: P1 3628800
// out: {n: 3, a: [...]}
// out: 42
// out: 8
// out: {id: 1, at: 2500ms}
// out: 1e+03 0.21875 0xff 1e+05 2
// out: 1+0i hi {si: hi}
