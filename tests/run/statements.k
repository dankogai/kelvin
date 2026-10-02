printf(fmt: const u8^, ...): i32;

enum color { RED, GREEN = 5, BLUE };
enum { LIMIT = 3 };

union number {
    i: i32;
    f: f32;
};

struct point { x: i32; y: i32; };

static counter: i32 = 0;

static bump(): i32
{
    static calls: i32;
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

    for (i: i32 = 0; i < LIMIT; i++)
        printf("%d", i);
    printf("\n");

    for (i: i32 = 0, j: i64 = 10; i < 2; i++, j--)
        printf("%d:%ld ", i, j);
    printf("\n");

    n: i32 = 0;
    do {
        n += 2;
    } while n < 5;
    printf("%d\n", n);

    k: i32 = 0;
again:
    if ++k < 3 {
        goto again;
    }
    printf("%d\n", k);

    bump();
    printf("%d\n", bump());

    u: union number;
    u.i = 0;
    u.f = 1.0;
    printf("%d\n", u.i != 0);

    p: struct point = origin();
    q: struct point = {.x = 1, .y = 2};
    pts: struct point[2] = {[1] = {.x = 9}};
    printf("%d %d %d %d\n", p.x, p.y, q.x + q.y, pts[1].x);

    if n == 6 { printf("six\n"); } else { printf("not six\n"); }
    while false {}
    if (n == 6) {           // parentheses are just grouping now
        printf("still six\n");
    }
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
// out: still six
