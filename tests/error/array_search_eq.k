// error: compares the elements, and pt has no '==': give a function that says which, '.firstIndex { ... }'
struct pt { x: int64 }

let main():int32 {
    var xs:Array<pt> = $[]
    println(xs.firstIndex((pt){1}))
    return 0
}
