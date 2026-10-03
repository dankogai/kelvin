// ranges (#28): for i in a..<b and for i in a...b; i is a let, and the
// bounds are evaluated once
#import <string.h> as C

var evaluations = 0;
limit(n:i64):i64 { evaluations += 1; return n; }

main():i32 {
    for i in 0..<3 {
        print(i, " ");
    }
    for i in 1...3 {
        print(i, " ");
    }
    for _ in 3..<3 {
        print("never");
    }
    println();

    // the bounds are evaluated once; i's type comes from them
    var sum = 0;
    for i in 0..<limit(4) {
        sum += i;
    }
    let s:cstr := "kelvin";
    var count = 0;
    for _ in 0..<strlen(s) {
        count += 1;
    }
    println(sum, " ", evaluations, " ", count);

    // a closed range up to the type's maximum ends
    var last:u8 = 0;
    var steps = 0;
    for b:u8 in 250...255 {
        last = b;
        steps += 1;
    }
    println(last, " ", steps);

    // continue and break work; a bound is an expression down to the shifts
    var odd = 0;
    for i in 0..<10 - 2 {
        if i % 2 == 0 {
            continue;
        }
        if i > 6 {
            break;
        }
        odd += 1;
    }
    println(odd);
    return 0;
}
// out: 0 1 2 1 2 3 
// out: 6 1 6
// out: 255 6
// out: 3
