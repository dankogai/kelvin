// a getter reads self and never changes it (#136)
struct pair { a: i64; b: i64 }
let pair[](i:i64):i64 {
    self.a = i
    return self.a
}
let main():i32 { return 0 }
// error: a let subscript and a var subscript's getter read self and never change it
