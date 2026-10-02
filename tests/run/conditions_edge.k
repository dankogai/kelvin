// regressions from the review of #23-#26
struct point { x: i32; y: i32; };
f(): i32 { return 1; }
isodd(n: i32): bool { return n % 2 == 1; }

main(): i32
{
    // ?: between two bools kelvinc sees is a bool, not C's int
    c = true;
    x = true;
    y = false;
    println(c ? x : y, " ", (c ? x : y).cstr, " ", c ? isodd(3) : isodd(4));
    if c ? x : y {
        println("ternary condition");
    }
    b = c ? x : y;
    z = c && (c ? x : y) && !(c ? y : x);
    println(b, " ", z);

    // sizeof(T) and a compound literal before a condition's {
    n: u64 = 16;
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
    p: struct point = {1, 2};
    if p.x == (struct point){1, 2}.x {
        println("compound literal");
    }

    // a comma expression as a condition
    i = 0;
    ok = true;
    if f(), ok {
        println("comma");
    }
    for (; f(), i < 4; i += 1) { }

    // each item of a list declares or assigns on its own
    a = 0;
    a = 1, d = 2;
    k = 1, a += 1;
    for (i = 0, j = 10; i < j; i += 1, j -= 1) { }
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
