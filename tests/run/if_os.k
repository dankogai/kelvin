// #if os(...) (#643), Swift's conditional compilation, of the platform
// kelvinc runs on: a branch not taken is read as text alone, so what is
// in it need not even be Kelvin; !, && and || join the conditions
#if os(Windows)
let kind():cstr { this is never read }
#elseif os(macOS) || os(Linux) || os(FreeBSD)
let kind():cstr { "unix" }
#else
let kind():cstr { "other" }
#endif
let main():int32 {
    println(kind())
    #if !os(Windows) && (os(macOS) || os(Linux) || os(FreeBSD))
    println("a unix, not Windows")
    #if os(Windows)
    println("never")
    #endif
    #else
    println("never either")
    #endif
    return 0
}
// out: unix
// out: a unix, not Windows
