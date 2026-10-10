// $ before a type is $[T] or ${K: V} (#64, #70)
let main():i32 {
    var x:$i64
    return 0
}
// error: '$' before a type: $[T] is Array<T> and ${K: V} Dictionary<K, V>, as $[a, b] and ${k: v} are the values; a String is written String
