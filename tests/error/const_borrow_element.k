// error: this changes what a const Dictionary<String, i64>^ points to, a read-only borrow, as a let's is: borrow a var, or take it without const
// nor an element of what it borrows (#273)
let reset(d:const Dictionary<String, int64>^) { d^["a"] = 0 }

let main():int32 { return 0 }
