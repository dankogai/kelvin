// error: 'box.empty' returns a bool, and this gives i64: compare it, as in 'x != 0'
struct box { n: int64 }

extend box {
    let empty():bool {
        let count = .n
        return count
    }
}

let main():int32 {
    return 0
}
