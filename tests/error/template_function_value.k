// error: a template cannot show a function: a function has no text
let square(x:int64):int64 { x * x }
let main():int32 {
    let f:(int64):int64 := square
    println(`${f}`)
    return 0
}
