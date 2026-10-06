// let and var (#27): a let never changes, and is C's const; parameters
// are lets unless written var; self is a mutable copy
#import <string.h> as C
struct point { x:i32; y:i32; };

let LIMIT = 3;                          // a global let
var calls:i32 = 0;

let length(var p:const u8^):i64 {           // a var parameter may change
    var n = 0;
    while p^ != 0 {
        n += 1;
        p := p.next;
    }
    return n;
}

let point.moved(dx:i32):struct point {      // self is a mutable copy
    self.x += dx;
    return self;
}

let twice(n:i64):i64 { return n * 2; }    // n is a let

let main():i32 {
    let name:cstr := "kelvin";
    let k = 42;
    let ok = k > LIMIT;
    let origin:struct point = {1, 2};
    let primes:i32[3] = {2, 3, 5};
    var total = 0;
    total += k;
    calls += 1;

    // a let pointer is fixed; what it points to is not
    var cell:i64 = 1;
    let p:i64^ := &cell;
    p^ = 7;

    println(length(name), " ", strlen(name), " ", twice(k), " ", ok, " ", total, " ", calls);
    println(origin.moved(5).cstr, " ", origin.cstr, " ", primes[2], " ", cell);
    return 0;
}
// out: 6 6 84 true 42 1
// out: {x: 6, y: 2} {x: 1, y: 2} 5 7
