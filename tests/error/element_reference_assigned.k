// an element that is a value is assigned with = (#755), as a variable
// is: kc says it of an element and of p^ too, where it built them
let main():int32 {
    var a:$[int64] = $[1]
    a[0] := 5
    return 0
}
// error: this target is a value (i64): assign it with '=', not ':='
