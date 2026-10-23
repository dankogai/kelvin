// async runs a function (#312): a method's self would be shared
struct box { n: int64 }
let box.get():int64 { .n }
let main():int32 {
    let b:box = {3}
    let t = async b.get()
    return 0
}
// error: 'async' runs a function, and this is a method, whose self the two threads would share: call a function, passing it what it needs
