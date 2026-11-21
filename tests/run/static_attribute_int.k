// a computed attribute of an integer type (#668), as <Prime>'s i64.primes:
// each read calls it; int64 is i64
static let i64.answer:i64 { 42 }
extend u32 {
    static let seven:u32 { 7 }
    static let evens:Iterator<u32> {
        return Iterator<u32>(0 as u32) {
            if $0 > 6 { return none }
            $0 += 2
            return $0
        }
    }
}
let main():int32 {
    println(i64.answer, " ", int64.answer + 1, " ", u32.seven, " ", uint32.seven * 2)
    println(u32.evens.map { $0 })
    return 0
}
// out: 42 43 7 14
// out: [2, 4, 6, 8]
