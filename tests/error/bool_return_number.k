// error: 'odd' returns a bool, and this gives a number: compare it, as in 'x != 0'
let odd(n:int64):bool { return n % 2 }

let main():int32 {
    println(odd(3))
    return 0
}
