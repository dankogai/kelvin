// anonymous functions (#32): lines, initializers and placement, from the
// second review
struct op {
    f:(i64):i64;
    g:(i64):i64;
};
struct box { v:i64; };
struct bag { xs:i64[3]; };
struct point { x:i32; y:i32; };

let apply(x:i64, f:(i64):i64):i64 { return f(x); }
let box.map(f:(i64):i64):box { return (box){f(self.v)}; }
let bag.each(f:(i64));                               // a prototype, then the method
let bag.each(f:(i64)) {
    for x in self.xs {
        f(x);
    }
}
let below(n:i64, f:(i64):bool):bool { return f(n); }
let tick(n:i64) { print(n, " "); }

// a function in a member's length, and globals of one declaration
struct holder { buf:u8[sizeof(apply(1) { $0 })]; };
var buf:u8[16], fill := { (a:u8[sizeof(buf)]) in a[0] = 1 };
let N:i64 = 3;
let total(xs:i64^, f:(i64[N]):i64):i64 { return f(xs); }

let main():i32 {
    // an operator or .member on the next line goes on with the expression
    let a:i64 = apply(3) { $0 * 2 }
        - apply(4) { $0 + 1 };
    let b:box = {1};
    let c:i64 = b.map() { $0 * 2 }
                 .map() { $0 + 1 }
                 .v;
    let d:i64 = (apply(3) { $0 * 2 }
                 + apply(4) { $0 + 1 });
    println(a, " ", c, " ", d);

    // initializer items that start with an annotation stay values
    let n:i32 = 4;
    let xs:i64[2] = [ (n:i64) * 2, 3 ];
    let ys:i64[2] = [ (n:u8):i64, 2 ];
    let ops:op[2] = [{{ $0 + 1 }, { $0 - 1 }}, {{ $0 * 2 }, { $0 / 2 }}];
    println(xs[0], " ", ys[0], " ", ops[1].f(5), " ", ops[0].g(5));

    // ?: picks functions, also nullptr; a compound literal ends a line
    let on = true;
    let t:(i64) := on ? tick as (i64) : nullptr;
    let pick:(i64):i64 := on ? { (x:i64):i64 in x + 1 } : { (x:i64):i64 in x - 1 };
    let mk:(i64):point := {
        $0 > 0 ? (point){1, 2}
               : (point){3, 4}
    };
    t(7);
    println(pick(1), " ", mk(-1).x);

    // a method with a prototype, := through a cast, do ... while
    let g:bag = {[1, 2, 3]};
    g.each() { print($0) }
    println();
    var o:op;
    var p:any^ := &o;
    (p as op^)^.f := { $0 * 10 };
    var k:i64 = 0;
    do {
        k += 1;
    } while below(k) { $0 < 3 };
    println(o.f(2), " ", k);

    // placement, sizes, and a length of global names, which is kept
    var h:holder;
    fill(buf);
    var six:i64[6] = [1, 2, 3, 4, 5, 0];
    println(h.size, " ", buf[0], " ", apply.size == sizeof(any^), " ", total(six) {
        var s:i64 = 0;
        for x in $0 {
            s += x;
        }
        return s;
    });
    return 0;
}
// out: 1 3 11
// out: 8 4 10 4
// out: 7 2 3
// out: 123
// out: 20 3
// out: 8 1 true 6
