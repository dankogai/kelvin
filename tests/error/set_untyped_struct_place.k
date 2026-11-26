// a Set of no type written whose element is a struct's variable is
// refused at the element (#780), where kelvinc said it at the type of
// the variable's declaration, two lines above
struct pt { x:int64, y:int64 }
let main():int32 {
    var o:pt = {1, 2}

    var s = ${o}
    return 0
}
// error: a key of a Dictionary is an integer or a String, not struct pt
