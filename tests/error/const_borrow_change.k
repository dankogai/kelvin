// error: this changes what a const Array<i64>^ points to, a read-only borrow, as a let's is: borrow a var, or take it without const
// a const $[T]^ reads and does not change (#273)
let grow(xs:const $[int64]^) { xs^ += 4 }

let main():int32 { return 0 }
