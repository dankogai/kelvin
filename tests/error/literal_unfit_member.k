// of a member of a struct's literal (#663)
struct p { c:u8 }
let main():int32 {
    let q:p = {999}
    println(q.c)
    return 0
}
// error: 999 does not fit u8, whose values are 0 to 255
