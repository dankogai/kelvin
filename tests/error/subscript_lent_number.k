// lent is for an owner, of a subscript's index as of a parameter (#510, #614)
struct box { n: i64 }
extend box {
    let [](i:lent i64):i64 { i + .n }
}
let main():int32 { return 0 }
// error: 'lent' is for an owner, a String, a Bytes, an Array, a Dictionary, a Set or a struct that owns: i64 is given as it is
