// an operator in extend T takes a T (#135)
struct money { cents: int64 }
struct other { n: int64 }
extend money {
    static let +(a:other, b:other):other { (other){a.n + b.n} }
}
let main():int32 { return 0 }
// error: an operator in extend money takes a money, as one of its values
