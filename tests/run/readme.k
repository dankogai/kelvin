// the first example in README.md, kept compiling
#import <stdio.h> as C

struct node {
    value:int32;
    next:node^;
};

let sum(var n:node^):int32 {      // n may move; parameters are lets otherwise
    var total:int32 = 0;
    while n != nullptr {
        total += n^.value;      // C: n->value
        n := n^.next;
    }
    return total;
}

let main():int32 {
    var c:node = {3, nullptr};
    var b:node = {2, &c};
    var a:node = {1, &b};
    println(sum(&a));
    return 0;
}
// out: 6
