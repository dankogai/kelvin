// $ before a type is only $[T] (#64)
let main():i32 {
    var x:$i64
    return 0
}
// error: '$' before a type: $[T] is Array<T>, as $[a, b] is Array([a, b]); a String is written String
