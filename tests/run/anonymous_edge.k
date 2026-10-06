// anonymous functions (#32), edge cases from review
#import <string.h> as C

struct ops {
    add:(i64, i64):i64;
    name:cstr;
};

var total:i64 = 0;
var other:i64 = 0;

let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let each(n:i64, f:(i64)) {
    for i in 0..<n {
        f(i);
    }
}
let run(f:()) { f(); }
let some(n:i64, f:(i64):bool):bool {
    for i in 0..<n {
        if f(i) {
            return true;
        }
    }
    return false;
}
let size_of(x:i64, f:(i64):size_t):size_t { return f(x); }

// globals of the same declaration, and the global itself, are in sight
let base:i64 = 10, plus_base:(i64):i64 := { $0 + base };
let fact:(i64):i64 := { $0 <= 1 ? 1 : $0 * fact($0 - 1) };

let main():i32 {
    // statements that end with trailing functions need no ';', and a new
    // line ends them, also before a '('
    run() {
        each(2) { total += $0 + 1 }
        each(1) { total += 10 }
    }
    var x:i64 = 0;
    var p:any^ := &x;
    each(1) { other += 1 }
    (p as i64^)^ = 42;
    println(total, " ", x, " ", other);

    // in an initializer list, a member's function type types the function
    let o:ops = {{ $0 - $1 }, "sub"};
    let q:ops = {.name = "mul", .add = { $0 * $1 }};
    println(o.name, " ", o.add(9, 2), " ", q.name, " ", q.add(6, 7));
    println(plus_base(1), " ", fact(5));

    // inside parentheses, and a converter's, a '{' after a call is the
    // last argument even in a condition
    if some(5, { $0 > 3 }) && (some(5) { $0 > 9 }) == false {
        println("some");
    }
    for i in 0..<i64(apply(1) { $0 + 1 }) {
        print(i);
    }
    println();

    // a declaration may end with one; a written signature takes the
    // result from the context when it has none; $0 names a written one
    let y:i64 = apply(1) { $0 + 1 }
    let ap:(i64, (i64):i64):i64 := apply;
    println(y, " ", ap(1) { $0 + 10 }, " ", apply(3) { (a:i64) in a * 2 }, " ", apply(4) { (a:i64):i64 in $0 + a });

    // a C function with char parameters, wrapped; sizeof of a parameter
    let cmp:(cstr, cstr):i32 := { strcmp($0, $1) };
    println(cmp("a", "b") < 0, " ", size_of(1) { sizeof($0) });
    return 0;
}
// out: 13 42 1
// out: sub 7 mul 42
// out: 11 120
// out: some
// out: 01
// out: 2 11 6 8
// out: true 8
