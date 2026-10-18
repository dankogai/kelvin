// $(...) (#181) gives the function's own arguments, in number
let fib(n:int64):int64 { n < 2 ? n : $(n - 2, 1) }
let main():int32 {
    return 0
}
// error: '$(...)' calls fib, which takes 1 argument, and this gives 2
