// anonymous functions (#32) as values, from the third review: called
// where they stand, in tables, and their sizes
#import <stddef.h> as C

struct entry {
    name:[u8](8);
    run:(i64):i64;
};
struct pair { a:i64; b:i64; };
struct holder {
    at:pair;
    f:(i64):i64;
};
struct sized {
    n:size_t;
    f:(i64):i64;
};

// placed in a union, an enum, and a struct that names itself
let apply(x:i64, f:(i64):i64):i64 { return f(x); }
union u {
    buf:[u8](sizeof(apply(1) { $0 }));
    n:i32;
};
enum e { WIDE = sizeof(apply(1) { $0 + 1 }) };
struct s { a:[u8](sizeof({ (p:s^):i64 in 1 }(nullptr))); };

let table:[entry](2) = [{"inc", { $0 + 1 }}, {"dbl", { $0 * 2 }}];

let inc(x:i64):i64 { return x + 1; }
let sum(n:size_t, xs:[i64](n)):i64 {
    var t:i64 = 0;
    for i in 0..<n {
        t += xs[i];
    }
    return t;
}
// a parameter's length names another parameter: $0 is then a pointer
let third(n:i64, a:[i64](n), f:([i64](n)):i64):i64 { return f(a); }
// a length inside a function type's parameter never reaches C
let run(n:size_t, xs:i64^, f:((size_t, [i64](n)):i64, size_t, i64^):i64):i64 { return f(sum, n, xs); }
let some(n:i64, f:(i64):bool):bool {
    for i in 0..<n {
        if f(i) {
            return true;
        }
    }
    return false;
}
let seven():i64 { return { (x:i64):i64 in x + 4 }(3); }

let main():i32 {
    // one that writes its parameters is a value: called where it stands
    let r:i64 = { (a:i64):i64 in a * 2 }(3);
    let hi := { () in print("hi ") };
    hi();
    println(r, " ", { (x:i64):i64 in x * 2 }(21), " ", seven());

    // a string or a struct value fills its member, so the next one is typed
    let p:pair = {1, 2};
    let h:holder = {p, { $0 * 3 }};
    let z:sized = {3, { $0 + 1 }};
    for t in table {
        print(t.name, " ", t.run(10), " ");
    }
    println(h.f(2), " ", z.f(1));

    // sizes of functions are a pointer's
    var fp:(i64):i64 := inc;
    let mul:(i32, i32):i64 := { $0 as i64 * $1 };
    println(inc.size == sizeof(any^), " ", sizeof(inc) == sizeof(any^), " ",
            ({ (x:i64):i64 in x }).size == sizeof(any^), " ", (&fp as any^) != nullptr, " ", mul(100000, 100000));

    var xs:[i64](3) = [1, 2, 3];
    var v:u;
    var w:s;
    while some(5, { $0 > 9 }) {
        println("never");
    }
    println(third(3, xs) { $0[2] }, " ", run(3, xs) { $0($1, $2) }, " ", v.buf.size, " ", WIDE, " ", w.a.size);
    return 0;
}
// out: hi 6 42 7
// out: inc 11 dbl 20 6 2
// out: true true true true 10000000000
// out: 3 6 8 8 8
