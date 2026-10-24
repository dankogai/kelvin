// and what it gives is an iterator, with a var next():T? (#321)
struct span { lo: int64; hi: int64 }
let span.makeIterator():int64 { .lo }
let main():int32 {
    let s:span = {1, 4}
    println(s.map { $0 * 2 })
    return 0
}
// error: a Sequence gives a fresh iterator by its makeIterator(), a let method that takes nothing and gives a value whose 'var next():T?' gives each value: write 'let span.makeIterator():I'
