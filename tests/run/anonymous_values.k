// anonymous functions (#32) as values, from the third review: called
// where they stand, in tables, and their sizes
#import <stddef.h> as C

struct entry {
    name:[uint8](8);
    run:(int64):int64;
};
struct pair { a:int64; b:int64; };
struct holder {
    at:pair;
    f:(int64):int64;
};
struct sized {
    n:size_t;
    f:(int64):int64;
};

// placed in a union, an enum, and a struct that names itself
let apply(x:int64, f:(int64):int64):int64 { return f(x); }
union u {
    buf:[uint8](sizeof(apply(1) { $0 }));
    n:int32;
};
enum e { WIDE = sizeof(apply(1) { $0 + 1 }) };
struct s { a:[uint8](sizeof({ (p:s^):int64 in 1 }(nullptr))); };

let table:[entry](2) = [{"inc", { $0 + 1 }}, {"dbl", { $0 * 2 }}];

let inc(x:int64):int64 { return x + 1; }
let sum(n:size_t, xs:[int64](n)):int64 {
    var t:int64 = 0;
    for i in 0..<n {
        t += xs[i];
    }
    return t;
}
// a parameter's length names another parameter: $0 is then a pointer
let third(n:int64, a:[int64](n), f:([int64](n)):int64):int64 { return f(a); }
// a length inside a function type's parameter never reaches C
let run(n:size_t, xs:int64^, f:((size_t, [int64](n)):int64, size_t, int64^):int64):int64 { return f(sum, n, xs); }
let some(n:int64, f:(int64):bool):bool {
    for i in 0..<n {
        if f(i) {
            return true;
        }
    }
    return false;
}
let seven():int64 { return { (x:int64):int64 in x + 4 }(3); }

let main():int32 {
    // one that writes its parameters is a value: called where it stands
    let r:int64 = { (a:int64):int64 in a * 2 }(3);
    let hi := { () in print("hi ") };
    hi();
    println(r, " ", { (x:int64):int64 in x * 2 }(21), " ", seven());

    // a string or a struct value fills its member, so the next one is typed
    let p:pair = {1, 2};
    let h:holder = {p, { $0 * 3 }};
    let z:sized = {3, { $0 + 1 }};
    for t in table {
        print(t.name, " ", t.run(10), " ");
    }
    println(h.f(2), " ", z.f(1));

    // sizes of functions are a pointer's
    var fp:(int64):int64 := inc;
    let mul:(int32, int32):int64 := { $0 as int64 * $1 };
    println(inc.size == sizeof(any^), " ", sizeof(inc) == sizeof(any^), " ",
            ({ (x:int64):int64 in x }).size == sizeof(any^), " ", (&fp as any^) != nullptr, " ", mul(100000, 100000));

    var xs:[int64](3) = [1, 2, 3];
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
