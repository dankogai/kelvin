// a struct is never C's: where no overload takes it, kelvinc says so in C
// terms, as the one function of the name is called with it
struct node { v: int64; next: node^ }
let length(n:node^):int64 { n == nullptr ? 0 : 1 + length(n^.next) }
let main():int32 {
    var a:node = {1, nullptr}
    println(length(a))
    return 0
}
// error: struct node
