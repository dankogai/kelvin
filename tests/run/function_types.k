// function types (#31): (T, U):R is C's pointer to a function
#import <stdio.h> as C
#import <string.h> as C

struct ops {
    combine:(int64, int64):int64;
    name:cstr;
};

let add(a:int64, b:int64):int64 { return a + b; }
let mul(a:int64, b:int64):int64 { return a * b; }

let fold(xs:int64^, n:size_t, start:int64, f:(int64, int64):int64):int64 {
    var acc:int64 = start;
    for i in 0..<n {
        acc = f(acc, xs[i]);
    }
    return acc;
}

// a function may return a function
let pick(product:bool):(int64, int64):int64 {
    if product {
        return mul;
    }
    return add;
}

var count:int32 = 0;
let tick() { count += 1; }

let sum(n:int32, ...):int64 { return n; }

let second(p:int64^):int64^ { return p.next; }

let main():int32 {
    var xs:[int64](4) = [1, 2, 3, 4];
    println(fold(xs, 4, 0, add), " ", fold(xs, 4, 1, mul), " ", fold(xs, 4, 1, pick(true)));

    // a function value is a reference: assigned with :=, nullptr by default
    var f:(int64, int64):int64;
    println(f == nullptr);
    f := add;
    let g:(int64, int64):int64 := f;
    println(f(2, 3), " ", g(4, 5), " ", pick(false)(6, 7), " ", f != nullptr);

    // no parameters, no result, and ... at the end
    let t:() := tick;
    t();
    t();
    let v:(int32, ...):int64 := sum;
    println(count, " ", v(3, 1, 2), " ", t.size == sizeof(any^));

    // in a struct
    let o:ops = {mul, "mul"};
    println(o.name, " ", o.combine(6, 7), " ", strncmp(o.cstr, "{combine: 0x", 12) == 0);

    // a type with no result inside ?:, and a result that is a pointer
    let c = true;
    let h:() := c ? t as () : tick;
    h();
    let s:(int64^):int64^ := second;
    println(count, " ", s(xs)^);
    return 0;
}
// out: 10 24 24
// out: true
// out: 5 9 13 true
// out: 2 3 true
// out: mul 42 true
// out: 3 2
