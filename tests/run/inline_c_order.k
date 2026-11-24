// #inline C at the top level stands where it is written (#197, #727):
// its C sees the globals and calls the functions written before it, and
// what is written after it, a global, a struct's member, a parameter,
// uses its types; among statements it is one of a block's or a case's
#import <stdio.h> as C
var counter:int64 = 40
let bump(n:int64):int64 { n + 1 }
#inline C {
typedef struct { long a, b; } cpair;
static long peek_counter(void) { return counter + bump(1); }
static cpair mk(long a, long b) { cpair p = {a, b}; return p; }
}
var origin:cpair = {1, 2}
struct holder { p:cpair, n:int64 }
let sum(p:cpair):int64 { p.a + p.b }
let later():int64 { 7 }
#inline C { static long use_later(void) { return later() + sum(mk(1, 1)); } }
let main():int32 {
    var h:holder = {mk(3, 4), 5}
    println(peek_counter(), " ", sum(origin), " ", sum(h.p), " ", h.n, " ", use_later())
    switch h.n {
    case 5:
        #inline C { puts("five"); }
    default:
        println("other")
    }
    if h.n == 5 {
        #inline C { h.n = 6; }
    }
    println(h.n)
    return 0
}
// out: 42 3 7 5 9
// out: five
// out: 6
