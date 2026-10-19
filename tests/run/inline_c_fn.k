// #inline C { ... } in a function (#198): C statements where they stand,
// seeing the locals by their C names, which are their own; a C return
// returns, freeing the owners it leaves as Kelvin's return does, and the
// C compiler checks what kelvinc cannot
#import <stdio.h> as C
let answer():int32 {
    #inline C { return 42; }
}
let sum(n:int32):int64 {
    var total:int64 = 0
    #inline C {
        for (int i = 1; i <= n; i++) { total += i; }   /* } in a comment */
    }
    return total
}
let early(n:int32):int64 {
    var xs = $[1, 2, 3]
    var t = $"freed as C leaves"
    #inline C { if (n > 0) return (int64_t)xs.count; }
    return t.count
}
let main():int32 {
    println(early(1), " ", early(0))
    var s = $"kelvin"
    var count = 0
    #inline C { count = (int)s.b.count; }
    println(answer(), " ", sum(10), " ", count)
    for i in 0..<3 {
        #inline C {
            if (i == 1) { printf("{one}\n"); }
        }
    }
    var doubled = $[1, 2, 3].map { (x:int64):int64 in
        var y:int64 = 0
        #inline C { y = x * 2; }
        return y
    }
    println(doubled)
    return 0
}
// out: 3 17
// out: 42 55 6
// out: {one}
// out: [2, 4, 6]
// c: count = (int)s.b.count;
