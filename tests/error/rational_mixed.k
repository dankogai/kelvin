// two widths of rational do not mix (#539): rat32(r) converts first
#import <Rational>
let main():int32 {
    println(rat8(1, 3) + rat32(1, 6))
    return 0
}
// error: no operator + takes rat8 and rat32: define one, as in 'let +(a:rat8, b:rat32):... { ... }'
