// a subscript has self, so it is not static (#136)
struct pair { a: int64; b: int64 }
extend pair {
    static let [](i:int64):int64 { 0 }
}
let main():int32 { return 0 }
// error: a subscript has self, so it is not static
