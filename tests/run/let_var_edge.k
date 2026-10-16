// regressions from the review of #27 and #28
#import <setjmp.h> as C

// a let parameter of a C typedef that is an array stays as C writes it
let jump(env:jmp_buf);

// a range up to a const bound: only the loop variable is const
let total(lens:const int32^, n:int32):int32 {
    var t:int32 = 0;
    for k in 0..<n {
        for _ in 0..<lens[k] {
            t += 1;
        }
    }
    return t;
}

let count(n:const int32):int32 {
    var c = 0;
    for _ in 1...n {
        c += 1;
    }
    return c;
}

let main():int32 {
    var env:jmp_buf;
    if setjmp(env) == 0 {
        jump(env);
    }
    let lens:[int32](3) = [1, 2, 3];
    println("back ", total(lens, 3), " ", count(4));
    return 0;
}

let jump(env:jmp_buf) { longjmp(env, 1); }
// out: back 6 4
