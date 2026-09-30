extern fn printf(fmt: *u8, ...) -> i32;

fn classify(n: i32) -> *u8 {
    if n < 0 {
        return "negative";
    } else if n == 0 {
        return "zero";
    } else {
        return "positive";
    }
}

fn fib(n: u64) -> u64 {
    if n < 2 { return n; }
    return fib(n - 1) + fib(n - 2);
}

fn main() {
    printf("%s %s %s\n", classify(-5), classify(0), classify(7));
    var i = 0;
    var evens = 0;
    while true {
        i += 1;
        if i > 10 { break; }
        if i % 2 == 1 { continue; }
        evens += i;
    }
    printf("%d\n", evens);
    for k in 0..5 {
        printf("%d", k);
    }
    printf("\n");
    for k in 3..3 {
        printf("never %d\n", k);
    }
    printf("%llu\n", fib(40 as u64 - 10));
    let neg: i64 = -3;
    for k in neg..0 {
        printf("%lld ", k);
    }
    printf("\n");
}
// out: negative zero positive
// out: 30
// out: 01234
// out: 832040
// out: -3 -2 -1 
