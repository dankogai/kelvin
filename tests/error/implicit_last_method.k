// error: this value would be dropped: a body returns its value without 'return' only when it is one expression, so write 'return' before it
// the value of a method is dropped at a body's end as a function's is
// (#286): on either arm of an if, of a receiver the body is given
struct box { n:int64 }
let box.twice():int64 { return .n * 2 }
let chosen(b:box, c:bool):int64 { if c { b.twice() } else { b.twice() } }
let main():int32 {
    let b:box = {1}
    println(chosen(b, true))
    return 0
}
