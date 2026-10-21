// error: 'dx' of 'pt.moved' is an i64, and this is text
struct pt { x: int64 }
extend pt {
    let moved(dx:int64):pt { (pt){self.x + dx} }
}

let main():int32 {
    let p = (pt){1}
    println(p.moved("two"))
    return 0
}
