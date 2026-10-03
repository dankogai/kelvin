// regressions from the review of #27 and #28
#import <setjmp.h> as C

// a let parameter of a C typedef that is an array stays as C writes it
jump(env:jmp_buf);

// a range up to a const bound: only the loop variable is const
total(lens:const i32^, n:i32):i32 {
    var t:i32 = 0;
    for k in 0..<n {
        for _ in 0..<lens[k] {
            t += 1;
        }
    }
    return t;
}

count(n:const i32):i32 {
    var c = 0;
    for _ in 1...n {
        c += 1;
    }
    return c;
}

main():i32 {
    var env:jmp_buf;
    if setjmp(env) == 0 {
        jump(env);
    }
    let lens:i32[3] = {1, 2, 3};
    println("back ", total(lens, 3), " ", count(4));
    return 0;
}

jump(env:jmp_buf) { longjmp(env, 1); }
// out: back 6 4
