// function types (#31): (T, U):R is C's pointer to a function
#import <stdio.h> as C
#import <string.h> as C

struct ops {
    combine:(i64, i64):i64;
    name:cstr;
};

let add(a:i64, b:i64):i64 { return a + b; }
let mul(a:i64, b:i64):i64 { return a * b; }

let fold(xs:i64^, n:size_t, start:i64, f:(i64, i64):i64):i64 {
    var acc:i64 = start;
    for i in 0..<n {
        acc = f(acc, xs[i]);
    }
    return acc;
}

// a function may return a function
let pick(product:bool):(i64, i64):i64 {
    if product {
        return mul;
    }
    return add;
}

var count:i32 = 0;
let tick() { count += 1; }

let sum(n:i32, ...):i64 { return n; }

let second(p:i64^):i64^ { return p.next; }

let main():i32 {
    var xs:i64[4] = [1, 2, 3, 4];
    println(fold(xs, 4, 0, add), " ", fold(xs, 4, 1, mul), " ", fold(xs, 4, 1, pick(true)));

    // a function value is a reference: assigned with :=, nullptr by default
    var f:(i64, i64):i64;
    println(f == nullptr);
    f := add;
    let g:(i64, i64):i64 := f;
    println(f(2, 3), " ", g(4, 5), " ", pick(false)(6, 7), " ", f != nullptr);

    // no parameters, no result, and ... at the end
    let t:() := tick;
    t();
    t();
    let v:(i32, ...):i64 := sum;
    println(count, " ", v(3, 1, 2), " ", t.size == sizeof(any^));

    // in a struct
    let o:ops = {mul, "mul"};
    println(o.name, " ", o.combine(6, 7), " ", strncmp(o.cstr, "{combine: 0x", 12) == 0);

    // a type with no result inside ?:, and a result that is a pointer
    let c = true;
    let h:() := c ? t as () : tick;
    h();
    let s:(i64^):i64^ := second;
    println(count, " ", s(xs)^);
    return 0;
}
// out: 10 24 24
// out: true
// out: 5 9 13 true
// out: 2 3 true
// out: mul 42 true
// out: 3 2
