// extend names a type declared before it (#130)
extend shape {
    let f():int64 { 1 }
}
let main():int32 { return 0 }
// error: 'shape' is not a struct, union or enum declared before this extend
