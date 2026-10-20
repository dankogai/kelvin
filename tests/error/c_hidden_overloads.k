// error: twice(...) fits none of its 2 overloads: C's function of the name is not called where a Kelvin function has it (#223)
struct vec { x: int64; y: int64 }
let twice(v:vec):vec { (vec){v.x * 2, v.y * 2} }
let twice(s:String):int64 { s.count as int64 * 2 }

let main():int32 {
    let p:int64^ := nullptr
    println(twice(p))
    return 0
}
