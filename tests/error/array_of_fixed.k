// an Array of fixed arrays is not here yet, as C returns no array from a
// function, and an Array's element is such a value; kc says it at the
// element's type, as kelvinc does (#705)
let main():int32 {
    var rows:Array<[i64](2)>
    return 0
}
// error: an Array of [i64](2) is not here yet: an element is a value C returns
