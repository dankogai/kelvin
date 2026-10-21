// error: '.x' is an i64, and this is text
struct pt { x: int64 }

let main():int32 {
    var p = (pt){1}
    p.x = "one"
    return 0
}
