// methods (#18): your own, on structs and built-in types
struct point { x: i32; y: i32; };

point.dist2(): i64
{
    return self.x * self.x + self.y * self.y;
}

point.scaled(k: i32): struct point
{
    return (struct point){self.x * k, self.y * k};
}

f64.half(): f64
{
    return self / 2;
}

main(): i32
{
    var pi = 3.141592653589793;
    var p: struct point = {3, 4};
    var q: struct point = p.scaled(2);
    println(p.dist2(), " ", q.cstr, " ", pi.half());
    var pp: struct point^ := &p;
    println(pp^.dist2(), " ", pp^.scaled(3).cstr);
    return 0;
}
// out: 25 {x: 6, y: 8} 1.5707963267948966
// out: 25 {x: 9, y: 12}
