// methods (#18): toString() on every type, fmt() a la Raku, and your own
struct point { x: i32; y: i32; };
struct segment { from: struct point; to: struct point; tag: u8^; };
struct poly { name: String; corners: struct point[3]; scale: f64; };
union number { i: i32; f: f32; };

// overrides the derived toString
struct money { cents: i64; };
money.toString(): String
{
    return (self.cents / 100.0).fmt("$%.2f");
}

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
    pi = 3.141592653589793;
    println(pi.fmt("%a"));                  // 0x1.921fb54442d18p+1
    println(pi.toString());                 // %.17g: lossless
    println(pi);                            // print keeps the shortest form
    println(0.1.toString(), " ", 1.0.toString(), " ", (0.1:f32).toString());
    println(42.toString(), " ", (-7:i8).toString(), " ", (~(0:u128)).toString());
    println(true.toString(), " ", "text".toString());

    // fmt: one directive, no length modifiers, the value converted to it
    n: i64 = -42;
    println(n.fmt("%5d"), "|", n.fmt("%-6d"), "|", 255.fmt("%#x"), "|", 42.fmt("%.2f"));
    println(pi.fmt("pi = %8.4f"), "|", 100.fmt("%d%%"), "|", true.fmt("%6s"), "|", "hi".fmt("%-4s"), "|");
    println(42.fmt("%d %d"), "|", 42.fmt("%ld"), "|", 3.9.fmt("%d"));

    // derived toString for structs, nested, with arrays
    p: struct point = {3, 4};
    q: struct point = p.scaled(2);
    s: struct segment = {p, q, "edge"};
    println(p.toString(), " ", s.toString());
    poly: struct poly = {"tri".toString(), {{0, 0}, {1, 0}, {0, 1}}, 1.5};
    println(poly.toString());
    u: union number = {.i = 1};
    println(u.toString());

    // user methods and overrides
    println(p.dist2(), " ", q.toString(), " ", pi.half());
    m: struct money = {1234};
    println(m.toString());
    pp: struct point^ = &p;
    println(pp^.toString());

    // a String is a value: copy it, pass it, read its bytes
    t: String = p.toString();
    copy: String = t;
    println(copy, " ", copy.bytes[0]);
    return 0;
}
// out: 0x1.921fb54442d18p+1
// out: 3.1415926535897931
// out: 3.141592653589793
// out: 0.10000000000000001 1 0.100000001
// out: 42 -7 340282366920938463463374607431768211455
// out: true text
// out:   -42|-42   |0xff|42.00
// out: pi =   3.1416|100%|  true|hi  |
// out: <invalid format>|<invalid format>|3
// out: {x: 3, y: 4} {from: {x: 3, y: 4}, to: {x: 6, y: 8}, tag: edge}
// out: {name: tri, corners: [{x: 0, y: 0}, {x: 1, y: 0}, {x: 0, y: 1}], scale: 1.5}
// out: <union number>
// out: 25 {x: 6, y: 8} 1.5707963267948966
// out: $12.34
// out: {x: 3, y: 4}
// out: {x: 3, y: 4} 123
