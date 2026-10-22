// error: 'xs' of 'total' is an Array<i64>^, which may change what it borrows, and this is const Array<i64>^, a let's: write const in the type taken, or borrow a var
// &xs of a let Array (#273): a function that only reads takes a const $[T]^
let total(xs:$[int64]^):int64 { return xs^.count as int64 }

let main():int32 {
    let xs = $[1, 2]
    println(total(&xs))
    return 0
}
