// a struct is never C's: where the one function of the name takes a
// borrow of it, kelvinc says so in Kelvin's words (#257), and names '&'
struct node { v: int64; next: node^ }
let length(n:node^):int64 { n == nullptr ? 0 : 1 + length(n^.next) }
let main():int32 {
    var a:node = {1, nullptr}
    println(length(a))
    return 0
}
// error: 'n' of 'length' is a node^, and this is node: give a borrow, '&a'
