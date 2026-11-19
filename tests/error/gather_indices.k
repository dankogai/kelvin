// xs.gather(ix) takes the indices as a $[i64] (#617)
let main():int32 {
    let ix:$[i32] = $[0]
    println($["a"].gather(ix))
    return 0
}
// error: '.gather' takes the indices as a $[i64] or an [i64](N), and this is Array<i32>
