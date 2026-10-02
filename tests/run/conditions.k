// conditions are bool (#23): if, while and do take no parentheses, and
// their bodies are blocks; comparisons, &&, || and ! give a bool
#import <stdio.h> as C
#import <string.h> as C
#import "include/conditions.h" as C

positive(n: i32): bool { return n > 0; }

main(): i32
{
    a = 1;
    b = 2;
    println(a == b, " ", a < b, " ", !(a < b), " ", a < b && b > 0, " ", sizeof(a < b));
    println((a < b).cstr, " ", a < b ? "yes" : "no", " ", a < b ? a > 0 : b > 9);

    if a < b {
        println("less");
    } else if a == b {
        println("same");
    } else {
        println("more");
    }
    if (a < b) {                     // parentheses are only grouping now
        println("grouped");
    }

    n: i32 = 3;
    steps = 0;
    while n > 0 {
        n--;
        steps++;
    }
    do {
        n++;
    } while n < 2;
    println(steps, " ", n);

    done: bool = false;
    while !done {
        done = true;
    }
    for (i: i32 = 0; i < 3 && !done; i++) println("never");

    // C functions: a bool result is a condition, an int result is compared
    if is_even(4) && count_of(2) != 0 && strlen("abc") == 3 {
        println("c functions");
    }
    ok: bool = positive(n) || is_even(n);
    println(ok, " ", positive(-1) ? 1 : 0);
    return 0;
}
// out: false true false true 1
// out: true yes true
// out: less
// out: grouped
// out: 3 2
// out: c functions
// out: true 0
