// declarations without `var` (#15), and `expr:T` (#16)
#import <stdio.h> as C
#import <stddef.h> as C
#import <unistd.h> as C

extern var optind:i32;             // a C global, declared so Kelvin knows it

var total = 0;                      // a global, inferred i64

let main():i32 {
    var x:i32 = 5;                 // explicit type
    var i = 42;                     // not declared yet: declares i: i64
    var u = 0xdead:u16;             // u: u16
    var w = 0xdead as u16;          // the same
    var f = 1.5;                    // f: f64
    var c = u8(300);                // c: u8
    var n = 5:size_t;               // a C typedef works after ':' too
    printf("%d %d %d %d %d %d\n", i32(sizeof i), i32(sizeof u), i32(sizeof w), i32(sizeof f),
           i32(sizeof c), i32(sizeof n));
    printf("%d %d %d\n", i32(u), c, x);

    i = 7;                      // declared: an assignment
    {
        i = 3;                  // still the outer i
        var y = 1;                  // a new name in this block
        total = total + y;      // the global
    }
    printf("%d %d\n", i32(i), i32(total));

    for (var k = 0; k < 3; k += 1)  // k is declared for the loop only
        total += k;
    var k = 10;                     // so this declares a new k
    printf("%d %d\n", i32(total), i32(k));

    var a:i32 = 1, b = 2;          // b is inferred
    var big:u64 = 1:u64 << 40;     // a typed literal instead of 1UL
    var flag:bool = true;
    var t:u8 = flag ? 1:u8 : 2:u8; // annotations inside a ternary
    printf("%d %d %d %d\n", a, i32(b), i32(big >> 40), t);

    optind = 1;                 // assigns the C global
    printf("%d\n", optind);
    return 0;
}
// out: 8 2 2 8 1 8
// out: 57005 44 5
// out: 3 1
// out: 4 10
// out: 1 2 1 1
// out: 1
