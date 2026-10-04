// v.type is v's type, wherever a type goes, and v.typename its Kelvin
// spelling as cstr (#34)
#import <stdlib.h> as C
#import <string.h> as C
#import <errno.h> as C
#import "include/event.h" as C

struct point { x:i32; y:i32; };
struct tagged { type:i32; v:i64; };

let k = 3;
var origin:point;

inc(x:i64):i64 { return x + 1; }
apply(x:i64, f:(i64):i64):i64 { return f(x); }
far(p:origin.type):origin.x.type { return p.x; }

main():i32 {
    // the type kelvinc sees, without a let's own const
    var w:k.type = 4;
    w += 1;
    let p := &w as w.type^;
    var pt:point = {1, 2};
    var q:pt.type = {3, 4};
    var xs:i32[4] = {1, 2, 3, 4};
    var ys:xs.type = {5, 6, 7, 8};
    let r:pt.x.type = 7;
    var pp:point^ := &pt;
    let ry:pp^.y.type = 9;
    println(w, " ", p^, " ", q.x, " ", ys[3], " ", r.size, " ", ry, " ", far(q));
    println(sizeof(w.type), " ", sizeof(pt.type), " ", (w as w.type) + 1, " ", ((pt.type){5, 6}).y);

    // its text: kelvinc's where it sees the type, else C's _Generic
    println(k.typename, " ", pt.typename, " ", p.typename, " ", xs.typename, " ", inc.typename, " ",
            pp^.typename);
    println(abs(-1).typename, " ", strlen("a").typename, " ", getenv("X").typename, " ", 42.typename, " ",
            (1 < 2).typename, " ", 1.5.typename);

    // a field named type stays a field
    var t:tagged = {2, 5};
    var ev:struct event;
    ev.type = 3;
    var copy:ev.type = ev;
    println(t.type, " ", sizeof(t.type), " ", ev.type, " ", sizeof(ev.type), " ", copy.type, " ",
            copy.v.typename);

    // what kelvinc cannot see is C's __typeof__
    var e:errno.type = 5;
    println(e, " ", e.typename, " ", apply(2) {
        var x:$0.type = $0;
        x *= 10;
        return x;
    });
    return 0;
}
// out: 5 5 3 8 4 9 3
// out: 8 8 6 6
// out: i64 point i64^ i32[4] (i64):i64 point
// out: i32 u64 u8^ i32 bool f64
// out: 2 4 3 4 3 i64
// out: 5 i32 20
