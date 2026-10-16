// error: a compound literal's '{' starts on the line of its '(type)': on the next line, '{' starts a block
struct point { x:int32; y:int32 }
let origin():point {
    return (point)
    {
        .x = 0,
        .y = 0
    }
}
let main():int32 {
    println(origin().x)
    return 0
}
