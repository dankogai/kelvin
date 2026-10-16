// an operator in extend is static, as Swift's static func (#135)
struct money { cents: int64 }
extend money {
    let +(a:Self, b:Self):Self { (Self){a.cents + b.cents} }
}
let main():int32 { return 0 }
// error: an operator in extend is a function of the type, as Swift's static func: write 'static let +(a:money, b:money):money { ... }'
