// a function defined inside a function (#180): a function of the program
// as one at the top level is, written where it is used, named in its block
// alone, hiding one of its name outside, calling itself and the globals,
// and seeing its parameters, not the locals around it
var calls:int64 = 0
let twice(n:int64):int64 { n * 2 }
let top():int64 { twice(2) }
let other():int64 {
    let twice(n:int64):int64 { n * 4 }           // another of the name, in another function
    return twice(5)
}
let main():int32 {
    let fib(n:int64):int64 {
        n < 2 ? n : fib(n-2)+fib(n-1)
    }
    let shout(s:cstr):() { calls += 1; println(s, "!") }
    let twice(n:int64):int64 { calls += 10; return n * 3 }   // hides the top level's in this block
    println(fib(10), " ", twice(2))
    shout("done")
    {
        let fib(n:int64):int64 { 42 }                 // a block's own, until its end
        println(fib(1))
    }
    println(fib(5), " ", calls, " ", other(), " ", top())
    return 0
}
// out: 55 6
// out: done!
// out: 42
// out: 5 11 20 4
// c: static int64_t _kv_main_fib(const int64_t n)
// c: static int64_t _kv_main_fib1(const int64_t n)
// c: static int64_t _kv_other_twice(const int64_t n)
