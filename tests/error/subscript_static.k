// a subscript has self, so it is not static (#136)
struct pair { a: i64; b: i64 }
extend pair {
    static let [](i:i64):i64 { 0 }
}
let main():i32 { return 0 }
// error: a subscript has self, so it is not static
