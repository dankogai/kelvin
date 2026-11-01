// a function with no result may return a call of no value (#427), as C's
// return of a void call does: one of the program's, or a method's
let note(n:int64) { println("note ", n) }
let pass(n:int64) {
    if n < 0 { return note(0 - n) }
    return note(n)
}
struct pt { x:int64 }
let pt.show() { return note(.x) }
let main():int32 {
    pass(-2)
    pass(3)
    let p:pt = {4}
    p.show()
    return 0
}
// out: note 2
// out: note 3
// out: note 4
