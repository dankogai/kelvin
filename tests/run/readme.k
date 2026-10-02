// the first example in README.md, kept compiling
#import <stdio.h> as C

struct node {
    value: i32;
    next: struct node^;
};

sum(var n: struct node^): i32       // n may move; parameters are lets otherwise
{
    var total: i32 = 0;
    while n != nullptr {
        total += n^.value;              // C: n->value
        n := n^.next;
    }
    return total;
}

main(): i32
{
    var c: struct node = {3, nullptr};
    var b: struct node = {2, &c};
    var a: struct node = {1, &b};
    println(sum(&a));
    return 0;
}
// out: 6
