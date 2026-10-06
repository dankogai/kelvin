// anonymous functions (#32): { ... } is a function of its own, with no
// closure; $0, $1 or $[k] are its parameters when their types are seen
#import <stdlib.h> as C
#import <string.h> as C

struct counter { hits:i64[3]; };

var total:i64 = 0;
let step = 10;

let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let each(xs:i64^, n:size_t, f:(i64)) {
    for i in 0..<n {
        f(xs[i]);
    }
}

let counter.each(f:(i64)) {
    for h in self.hits {
        f(h);
    }
}

let twice():(i64):i64 { return { $0 * 2 }; }

let fact(n:i64):i64 {
    if n <= 1 {
        return 1;
    }
    return apply(n) { $0 * fact($0 - 1) };   // the function around may be called
}

// a global initializer may be one too
let shout:(cstr) := { println($0, "!") };

let main():i32 {
    // the last argument, written after the call: no ';' needed
    println(apply(20) { $0 + 1 }, " ", apply(20, { $[0] - 1 }));
    var xs:i64[3] = {1, 2, 3};
    each(xs, 3) { total += $0 * step }      // globals are fine
    println(total);

    // a body of statements, with return
    println(apply(7) {
        var x:i64 = $0;
        x *= x;
        return x;
    });

    // written parameters, where kelvinc sees no type: C's qsort
    var ys:i32[4] = {3, 1, 4, 2};
    qsort(ys, 4, sizeof(i32)) { (a:const any^, b:const any^):i32 in
        let x:i32 = (a as const i32^)^;
        let y:i32 = (b as const i32^)^;
        return i32(x > y) - i32(x < y);
    }
    println(ys[0], ys[1], ys[2], ys[3]);

    // typed by a declaration, an assignment or a function's result
    let inc:(i64):i64 := { $0 + 1 };
    var op:(i64):i64 := inc;
    op := { $0 - 1 };
    let mul := { (a:i64, b:i64):i64 in a * b };
    println(inc(1), " ", op(1), " ", twice()(21), " ", mul(6, 7), " ", fact(5));

    // nested: $0 is the innermost function's
    println(apply(1) { apply($0 + 1) { $0 * 10 } });

    // methods, and no parameters at all
    var c:counter = {{4, 5, 6}};
    total = 0;
    c.each() { total += $0 }
    shout("done");
    atexit() { println("bye") }
    println(total);
    return 0;
}
// out: 21 19
// out: 60
// out: 49
// out: 1234
// out: 2 0 42 42 120
// out: 20
// out: done!
// out: 15
// out: bye
