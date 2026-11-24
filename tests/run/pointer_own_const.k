// T^ const and cstr const, a pointer that is itself const, C's T *const
// (#742): it is read, passed and named, const T^ const of both consts
// and const before restrict in either order written; what it points to
// changes through it; a variable inferred of it is a plain pointer,
// which points elsewhere (#738)
struct holder { p:int64^ const, n:int64 }
struct named { n:int64, s:cstr const }
let read(p:int64^ const):int64 { p^ }
let peek(p:int64^):int64 { p^ }
let main():int32 {
    var x:int64 = 1
    var y:int64 = 20
    var p:int64^ const := &x
    p^ += 1
    p[0] += 1
    println(p^, " ", read(p), " ", peek(p), " ", p.isNull, " ", p.typename)
    var c:const int64^ const := &x
    let pp:int64^ const^ := &p
    println(c^, " ", c.typename, " ", pp^^, " ", pp.typename, " ", (&p).typename)
    var r1:int64^ const restrict := &y
    var r2:int64^ restrict const := &y
    var r3:const int64^ restrict const := &y
    println(r1^, " ", r1.typename, " ", r2.typename, " ", r3.typename)
    var q := p
    println(q^, " ", q.typename)
    q := &y
    println(q^)
    var o:int64^? = p
    println(o.is(some))
    var h:holder = {&x, 3}
    var g:holder = h
    h.p^ = 7
    println(g.p^, " ", h.p.typename, " ", read.typename)
    var s:cstr const := "abc"
    var m:named = {1, s}
    var t := m.s
    println(s, " ", s.typename, " ", m.s, " ", t.typename, " ", s.count, " ", s[1])
    t := "z"
    println(t)
    var s1:cstr const restrict := "r"
    var s2:cstr restrict const := "r"
    println(s1.typename, " ", s2.typename)
    var ps:[int64^ const](2) = [&x, &y]
    println(ps[0]^ + ps[1]^, " ", ps.typename)
    return 0
}
// out: 3 3 3 false i64^ const
// out: 3 const i64^ const 3 i64^ const^ i64^ const^
// out: 20 i64^ const restrict i64^ const restrict const i64^ const restrict
// out: 3 i64^
// out: 20
// out: true
// out: 7 i64^ const (i64^ const):i64
// out: abc cstr const abc cstr 3 98
// out: z
// out: cstr const restrict cstr const restrict
// out: 27 [i64^ const](2)
