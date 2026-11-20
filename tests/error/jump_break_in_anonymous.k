// an anonymous function is a body of its own: the loop around it does
// not hold its break (#649)
let main():int32 {
    for i in 0..<3 {
        let f := { (x:i64):i64 in
            break
            return x
        }
        println(f(i))
    }
    return 0
}
// error: 'break' leaves a loop or a switch, and this is in neither
