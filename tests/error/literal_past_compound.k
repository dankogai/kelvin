// a compound literal of a struct past its last member (#647)
struct p { x:i64 }
let main():int32 {
    let q = (p){1, 2}
    println(q.x)
    return 0
}
// error: p has 1 member, and this gives 2
