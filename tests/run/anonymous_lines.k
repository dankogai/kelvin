// anonymous functions (#32): lines, initializers and placement, from the
// second review
struct op {
    f:(int64):int64;
    g:(int64):int64;
};
struct box { v:int64; };
struct bag { xs:[int64](3); };
struct point { x:int32; y:int32; };

let apply(x:int64, f:(int64):int64):int64 { return f(x); }
let box.map(f:(int64):int64):Self { return (Self){f(.v)}; }
let bag.each(f:(int64));                               // a prototype, then the method
let bag.each(f:(int64)) {
    for x in .xs {
        f(x);
    }
}
let below(n:int64, f:(int64):bool):bool { return f(n); }
let tick(n:int64) { print(n, " "); }

// a function in a member's length, and globals of one declaration
struct holder { buf:[uint8](sizeof(apply(1) { $0 })); };
var buf:[uint8](16), fill := { (a:[uint8](sizeof(buf))) in a[0] = 1 };
let N:int64 = 3;
let total(xs:int64^, f:([int64](N)):int64):int64 { return f(xs); }

let main():int32 {
    // an operator or .member on the next line goes on with the expression
    let a:int64 = apply(3) { $0 * 2 }
        - apply(4) { $0 + 1 };
    let b:box = {1};
    let c:int64 = b.map() { $0 * 2 }
                 .map() { $0 + 1 }
                 .v;
    let d:int64 = (apply(3) { $0 * 2 }
                 + apply(4) { $0 + 1 });
    println(a, " ", c, " ", d);

    // initializer items that start with an annotation stay values
    let n:int32 = 4;
    let xs:[int64](2) = [ (n:int64) * 2, 3 ];
    let ys:[int64](2) = [ (n:uint8):int64, 2 ];
    let ops:[op](2) = [{{ $0 + 1 }, { $0 - 1 }}, {{ $0 * 2 }, { $0 / 2 }}];
    println(xs[0], " ", ys[0], " ", ops[1].f(5), " ", ops[0].g(5));

    // ?: picks functions, also nullptr; a compound literal ends a line
    let on = true;
    let t:(int64) := on ? tick as (int64) : nullptr;
    let pick:(int64):int64 := on ? { (x:int64):int64 in x + 1 } : { (x:int64):int64 in x - 1 };
    let mk:(int64):point := {
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
    var k:int64 = 0;
    do {
        k += 1;
    } while below(k) { $0 < 3 };
    println(o.f(2), " ", k);

    // placement, sizes, and a length of global names, which is kept
    var h:holder;
    fill(buf);
    var six:[int64](6) = [1, 2, 3, 4, 5, 0];
    println(h.size, " ", buf[0], " ", apply.size == sizeof(any^), " ", total(six) {
        var s:int64 = 0;
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
