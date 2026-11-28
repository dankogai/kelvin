// a function's type names a struct by its word where a function given
// with = is refused (#789), as kelvinc spells it: kc said (pt):i64
struct pt { x:int64, y:int64 }

let main():int32 {
    let f = { (o:pt):int64 in o.x }
    return 0
}
// error: 'f' is a reference ((struct pt):i64): assign it with ':=', not '='
