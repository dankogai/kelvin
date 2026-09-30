printf(fmt: const u8^, ...): i32;

enum color { RED, GREEN = 5, BLUE };
enum { LIMIT = 3 };

union number {
    i: i32;
    f: f32;
};

struct point { x: i32; y: i32; };

static var counter: i32 = 0;

static bump(): i32
{
    static var calls: i32;
    calls++;
    return ++counter + calls * 0;
}

name(c: enum color): const u8^
{
    switch (c) {
    case RED:
        return "red";
    case GREEN:
        return "green";
    default:
        break;
    }
    return "other";
}

origin(): struct point
{
    return (struct point){.y = 7};
}

main(): i32
{
    printf("%s %s %s %d\n", name(RED), name(GREEN), name(BLUE), BLUE);

    for (var i: i32 = 0; i < LIMIT; i++)
        printf("%d", i);
    printf("\n");

    for (var i: i32 = 0, j: i64 = 10; i < 2; i++, j--)
        printf("%d:%ld ", i, j);
    printf("\n");

    var n: i32 = 0;
    do {
        n += 2;
    } while (n < 5);
    printf("%d\n", n);

    var k: i32 = 0;
again:
    if (++k < 3)
        goto again;
    printf("%d\n", k);

    bump();
    printf("%d\n", bump());

    var u: union number;
    u.i = 0;
    u.f = 1.0f;
    printf("%d\n", u.i != 0);

    var p: struct point = origin();
    var q: struct point = {.x = 1, .y = 2};
    var pts: struct point[2] = {[1] = {.x = 9}};
    printf("%d %d %d %d\n", p.x, p.y, q.x + q.y, pts[1].x);

    if (n == 6) printf("six\n"); else printf("not six\n");
    while (0) ;
    return 0;
}
// out: red green other 6
// out: 012
// out: 0:10 1:9 
// out: 6
// out: 3
// out: 2
// out: 1
// out: 0 7 3 9
// out: six
