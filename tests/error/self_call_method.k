// $(...) (#181) in a method is written self.name(...), since the method has
// a receiver to call it on
struct node { n: int64 }
extend node {
    let depth(k:int64):int64 { k <= 0 ? .n : $(k - 1) }
}
let main():int32 {
    return 0
}
// error: '$(...)' calls the function around it, and this is a method of node: write 'self.depth(...)'
