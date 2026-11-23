// a type with no name inside a struct: one defined inside another is
// named by its path, point.kind, so it has a name (#389); kc says so as
// kelvinc does (#702)
struct shape {
    union { i:int32, f:float32 }
    n:int64
}
let main():int32 { return 0 }
// error: expected a name, found 'union'
