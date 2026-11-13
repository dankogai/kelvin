// an attribute written after its use is seen (#544), so one called with
// parentheses is told so, as one written before is (#131)
struct p { x: i64 }
let main():int32 {
    let v:p = {3}
    println(v.sq())
    return 0
}
let p.sq:i64 { self.x * self.x }
// error: 'sq' is an attribute of p: read it as '.sq', with no parentheses
