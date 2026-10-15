// methods (#18): your own, on structs and built-in types
struct point { x:i32; y:i32; };

let point.dist2():i64 {
    return .x * .x + .y * .y;
}

let point.scaled(k:i32):struct point {
    return (struct point){.x * k, .y * k};
}

let f64.half():Self {
    return self / 2;
}

let main():i32 {
    var pi = 3.141592653589793;
    var p:struct point = {3, 4};
    var q:struct point = p.scaled(2);
    println(p.dist2(), " ", q.cstr, " ", pi.half());
    var pp:struct point^ := &p;
    println(pp^.dist2(), " ", pp^.scaled(3).cstr);
    return 0;
}
// out: 25 {x: 6, y: 8} 1.5707963267948966
// out: 25 {x: 9, y: 12}
