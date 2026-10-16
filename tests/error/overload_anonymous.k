// where the overloads differ in a function parameter's types, an anonymous
// function writes them (#41)
let apply(f:(int64):int64, n:int64):int64 { f(n) }
let apply(f:(float64):float64, x:float64):float64 { f(x) }
let main():int32 {
    println(apply({ $0 * 2 }, 3))
    return 0
}
// error: kelvinc cannot see this anonymous function's parameters
