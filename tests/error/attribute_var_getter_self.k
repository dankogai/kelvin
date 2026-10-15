// a var attribute's getter reads self; its setter changes it (#137)
struct counter { n: i64 }
var counter.value:i64 {
    get {
        self = {0}
        return self.n
    }
    set(v) { self.n = v }
}
let main():i32 { return 0 }
// error: a let attribute and a var attribute's getter read self and never change it
