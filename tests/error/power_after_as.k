// '**' binds tighter than 'as', as it does than a prefix (#380)
let main():int32 {
    let n:int64 = 2
    println(n as float64 ** 2)
    return 0
}
// error: '**' binds tighter than 'as': write '(x as T) ** y'
