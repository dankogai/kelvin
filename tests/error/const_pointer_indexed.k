// p[i] through a const T^ is what it points to, as p^ is (#273, #733)
let main():int32 {
    var a:[int64](3) = [1, 2, 3]
    let p:const int64^ := &a[0]
    p[2] = 5
    return 0
}
// error: this changes what a const i64^ points to, a read-only borrow, as a let's is: borrow a var, or take it without const
