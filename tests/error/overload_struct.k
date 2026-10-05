// a struct is never C's: where no overload takes it, kelvinc says so in C
// terms, as the one function of the name is called with it
struct node { v: i64; next: node^ }
length(n:node^):i64 { n == nullptr ? 0 : 1 + length(n^.next) }
main():i32 {
    var a:node = {1, nullptr}
    println(length(a))
    return 0
}
// error: 'struct node'
