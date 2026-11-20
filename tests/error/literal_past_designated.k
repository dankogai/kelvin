// a value after a designator of the last member is past it (#647)
struct p { x:i64; y:i64 }
let main():int32 {
    let q:p = {.y = 1, 2}
    println(q.x)
    return 0
}
// error: p has 2 members, and this value is past its last
