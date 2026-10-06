// v.type and v.typename (#34), edge cases from review
#import <errno.h> as C
#import <setjmp.h> as C
#import "include/typeof.h" as C

enum { len = 3 };
enum color { red, green };
struct box { xs:[i32](len); };
struct point { x:i32; y:i32; };

// a prelude without <limits.h> leaves its names free
let CHAR_BIT:i64 = 7;
let INT_MAX:i64 = 100;

var calls:i64 = 0;
let next_len():i64 {
    calls += 1;
    return calls + 2;
}
let inc(x:i64):i64 { return x + 1; }
let g(s:struct cpt, x:s.x.type):i32 { return s.x + x; }
let sum(a:nums.type):i32 {
    var p:a.type := a;          // a parameter's C type: a pointer
    return p[0] + p[2];
}
let depth(j:jmp_buf):bool {
    var k:j.type := j;
    return sizeof(k) == sizeof(any^);
}
let apply(p:point, f:(point):i32):i32 { return f(p); }
let twice(x:i32, f:(i32):i32):i32 { return f(f(x)); }
let viatype(f:g_fp.type, x:i32):i32 { return f(x); }

let main():i32 {
    // C's __typeof__ keeps what kelvinc would evaluate again: a length
    // that is not a number keeps its own value
    var bx:box;
    let len = 10;
    var c:bx.xs.type;
    var n:i64 = 3;
    var a:[i32](n);
    n = 10;
    var b:a.type;
    var d:[i32](next_len());
    var e:d.type;
    println(c.size, " ", b.size, " ", sizeof(a.type), " ", e.size, " ", calls, " ", len);

    // const on an array's type is on its elements; a counter has none
    var xs:[i32](3) = [1, 2, 3];
    var ys:const xs.type = [4, 5, 6];
    for i:limit.type in 0..<limit {
        print(i);
    }
    var m:limit.type = 2;
    for i in 0..<m {
        print(i);
    }
    println(" ", ys.typename);

    // functions, parameters, enumerators and $0
    var gp:g.type := g;
    var jb:jmp_buf;
    let p:point = {1, 2};
    println(gp(corigin, 2), " ", sum(nums), " ", depth(jb), " ", sizeof(inc.type), " ", sizeof(red.type), " ",
            apply(p) { ($0.type){$0.y, $0.x}.x }, " ", twice(2) { ($0:$0.type) * 3 }, " ",
            viatype({ (x:i32):i32 in return x * 3; }, 5));

    // compound literals of an unseen type, and in a for head
    let ev:i32 = (const errno.type){6};
    var ev2:errno.type = (errno.type){7};
    for x in (xs.type)[7, 8, 9] {
        print(x);
    }
    println(" ", ev, " ", ev2, " ", { (k:i64):k.type in k + 1 }(4), " ", CHAR_BIT + INT_MAX);

    // .typename: a literal is C's, nullptr is any^, a choice of one type is
    // that type, a C struct is spelled so, and anything else is "?"
    var f:inc.type := inc;
    let w = true;
    var q:point = {3, 4};
    var cs:struct cpt;
    println(nullptr.typename, " ", 42.typename, " ", (w ? p : q).typename, " ", cs.typename, " ",
            (&f).typename, " ", b.typename, " ", (w ? p : q).cstr);
    return 0;
}

// out: 12 12 12 12 1 10
// out: 012301 [const i32](3)
// out: 3 4 true 8 4 2 18 15
// out: 789 6 7 5 107
// out: any^ i32 point struct cpt ((i64):i64)^ ? {x: 1, y: 2}
