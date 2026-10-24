// nor is a value a call gives, whose change would be lost (#318)
struct counter { n: int64 }
var counter.bump() { .n += 1 }
let make():counter { return {1} }
let main():int32 {
    make().bump()
    return 0
}
// error: '.bump' is a var method, which changes the value it is called on, so that value is a variable
