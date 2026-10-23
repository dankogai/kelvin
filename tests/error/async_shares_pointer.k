// async f(x) passes values, copied, and owners, moved (#312): a pointer
// parameter would share what it points to with the call's thread
let get(p:int64^):int64 { p^ }
let main():int32 {
    var n:int64 = 1
    let t = async get(&n)
    return 0
}
// error: 'async' would share what this points to with the call's thread: the parameter is i64^, and the function takes values, copied, and owners, moved
