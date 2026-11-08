// cookies (#489): a CookieJar in RequestInit keeps each answer's
// Set-Cookie, a redirect's too, and each request sends those whose domain,
// path and Secure match, as RFC 6265 has it; Max-Age and Expires end one, a
// Domain must match the host and hold a dot, a Secure one comes only over
// https. res.setCookies is each Set-Cookie apart, as headers joins them.
// Without a jar nothing is kept
#import <fetch>
let main(argc:int32, argv:u8^^):int32 {
    let base:cstr := argv[1]
    let port:cstr := &base[17]                  // http://127.0.0.1:PORT
    var jar = CookieJar()
    println(jar.count, " [", jar.getCookieString(base), "]")
    var set = fetch(`${base}/setcookie`, (RequestInit){.cookies = jar})
    println(set.ok.setCookies.count, " ", set.ok.setCookies[1])
    println(jar.count, " [", jar.getCookieString(`${base}/x`), "]")
    var echo = fetch(`${base}/cookie`, (RequestInit){.cookies = jar})
    print(echo.ok.text() ?? $"")
    var deep = fetch(`${base}/deep/setcookie`, (RequestInit){.cookies = jar})
    var d1 = fetch(`${base}/deep/cookie`, (RequestInit){.cookies = jar})
    var d2 = fetch(`${base}/cookie`, (RequestInit){.cookies = jar})
    print(deep.ok.status, " ", d1.ok.text() ?? $"", d2.ok.text() ?? $"")
    var login = fetch(`${base}/login`, (RequestInit){.cookies = jar})
    print(login.ok.redirected, " ", login.ok.text() ?? $"")
    var mine = fetch(`${base}/cookie`, (RequestInit){.cookies = jar, .headers = ${"Cookie": $"mine=0"}})
    print(mine.ok.text() ?? $"")
    var out = fetch(`${base}/logout`, (RequestInit){.cookies = jar})
    println(out.ok.status, " [", jar.getCookieString(base), "]")
    var other = fetch(`http://localhost:${port}/cookie`, (RequestInit){.cookies = jar})
    print(other.ok.text() ?? $"")
    var hd = fetch(`http://localhost:${port}/hostdomain`, (RequestInit){.cookies = jar})
    println(hd.ok.status, " [", jar.getCookieString(`http://localhost:${port}/`), "] [", jar.getCookieString(`http://www.localhost:${port}/`), "]")
    let t = jar.setCookie("t=9; Path=/x", base)
    let u = jar.setCookie("u=1; Domain=org", base)
    println(t, " ", u, " [", jar.getCookieString(`${base}/x/y`), "]")
    var none = fetch(`${base}/login`)
    print(none.ok.text() ?? $"")
    jar.clear()
    println(jar.count)
    return 0
}
// out: 0 []
// out: 8 b=2; Max-Age=3600
// out: 3 [a=1; b=2; c=3]
// out: cookie: a=1; b=2; c=3
// out: 200 cookie: p=deep; a=1; b=2; c=3
// out: cookie: a=1; b=2; c=3
// out: true cookie: a=1; b=2; c=3; session=abc
// out: cookie: mine=0; a=1; b=2; c=3; session=abc
// out: 200 [a=1; b=2; c=3]
// out: cookie: None
// out: 200 [h=1] []
// out: true false [t=9; a=1; b=2; c=3]
// out: cookie: None
// out: 0
