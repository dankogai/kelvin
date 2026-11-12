// a method of a built-in type, a number's, a bool's or a String's, may be
// called before it is written (#543), as a struct's may (#505): kelvinc
// writes its prototype, of let i64.m() and of extend i64 { }, where it is
// needed; of a literal too, which is the i64 it is (#538)
let main():int32 {
    let n:i64 = 3
    let x:f64 = 9.0
    let h:u8 = 7
    println(n.later(), " ", 4.later(), " ", (1 << 40).later(), " ", n.later(10), " ", x.half(), " ", h.plus(1))
    var s = $"ab"
    println(s.twice(), " ", s.shout(), " ", true.word(), " ", n.later().later())
    return 0
}
let i64.later():i64 { self * 2 }
extend i64 {
    let later(by:i64):i64 { self * by }
}
extend f64 {
    let half():f64 { self / 2.0 }
}
let u8.plus(n:u8):u8 { self + n }
let String.twice():String {
    var t = self.copy()
    t += &self
    return t
}
extend String {
    let shout():String {
        var t = self.copy()
        t += "!"
        return t
    }
}
let bool.word():cstr { self ? "yes" : "no" }
// out: 6 8 2199023255552 30 4.5 8
// out: abab ab! yes 12
