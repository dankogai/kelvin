// a var method changes the caller's var (#318), which a let is not
struct counter { n: int64 }
var counter.bump() { .n += 1 }
let main():int32 {
    let c:counter = {1}
    c.bump()
    return 0
}
// error: '.bump' is a var method, which changes 'c', a let: declare it with var
