// a value past a struct's last member is kelvinc's error (#647), where C
// only warned and dropped it
struct p { x:i64 }
let main():int32 {
    let q:p = {1, 2}
    println(q.x)
    return 0
}
// error: p has 1 member, and this gives 2
