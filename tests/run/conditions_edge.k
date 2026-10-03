// regressions from the review of #23-#26
struct point { x:i32; y:i32; };
f():i32 { return 1; }
isodd(n:i32):bool { return n % 2 == 1; }

main():i32 {
    // ?: between two bools kelvinc sees is a bool, not C's int
    var c = true;
    var x = true;
    var y = false;
    println(c ? x : y, " ", (c ? x : y).cstr, " ", c ? isodd(3) : isodd(4));
    if c ? x : y {
        println("ternary condition");
    }
    var b = c ? x : y;
    var z = c && (c ? x : y) && !(c ? y : x);
    println(b, " ", z);

    // sizeof(T) and a compound literal before a condition's {
    var n:u64 = 16;
    if n > sizeof(i64) {
        println("big");
    }
    while n > sizeof(i64) {
        n -= 1;
    }
    if n == sizeof(i32) {
    }
    {
        println("a block of its own");
    }
    var p:struct point = {1, 2};
    if p.x == (struct point){1, 2}.x {
        println("compound literal");
    }

    // a comma expression as a condition
    var i = 0;
    var ok = true;
    if f(), ok {
        println("comma");
    }
    for (; f(), i < 4; i += 1) { }

    // a list either declares (let or var) or assigns (#27)
    var a = 0;
    a = 1;
    var d = 2, k = 1;
    a += 1;
    var j = 10;
    for (i = 0; i < j; i += 1, j -= 1) { }
    println(n, " ", a, " ", d, " ", k, " ", i);
    return 0;
}
// out: true true true
// out: ternary condition
// out: true true
// out: big
// out: a block of its own
// out: compound literal
// out: comma
// out: 8 2 2 1 5
