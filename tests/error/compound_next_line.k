// error: a compound literal's '{' starts on the line of its '(type)': on the next line, '{' starts a block
struct point { x:i32; y:i32 }
let origin():point {
    return (point)
    {
        .x = 0,
        .y = 0
    }
}
let main():i32 {
    println(origin().x)
    return 0
}
