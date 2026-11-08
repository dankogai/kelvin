// modules/fetch.k - fetch(url) and fetch(url, init) (#482, #483), JS's fetch:
// the Response of a request of an http or https URL, a GET, or the method,
// headers and body of a RequestInit, or what went wrong, as a
// Result<Response, Error>.
// Written in Kelvin over libkfetch, runtime/fetch.c, an HTTP/1.1 client of
// its own; HTTPS is OpenSSL's where libkfetch was built with HAS_SSL=1.
// Built by kelvinc --lib into fetch.kh and the library that #import <fetch>
// links, with modules/libkfetch.link's flags.
//
//     #import <fetch>
//     var r = fetch("https://example.com/")
//     if let res = r {
//         println(res.status, " ", res.headers["content-type"])
//         println(res.text() ?? $"(not UTF-8)")       // or res.json(), a Result<JSON, Error>
//     } else {
//         println(r.err.message)
//     }
//     var p = fetch("https://example.com/api", (RequestInit){.method = $"POST",
//                   .headers = ${"content-type": $"application/json"}, .body = Bytes("{}")})
#import <kfetch.h> as C
#import <JSON>

// the engine's functions, by their C names
let kfetch_request(url:cstr, method:cstr, given:const Bytes^, sent:const Bytes^, redirect:i64, status:i64^, text:String^, final:String^, redirects:i64^, headers:Bytes^, body:Bytes^, error:String^):bool
let kfetch_header(headers:const Bytes^, i:i64, name:String^, value:String^):bool
let kfetch_has_ssl():bool

// what went wrong: a URL, a method or a header that is not one, the host not
// found, no connection, TLS, an answer that is no HTTP, a redirect where it
// was to be an error, HTTPS where it is not built in, a body that is not text
struct Error {
    message: String
}

// what a redirect does, as JS's init.redirect: follow it, up to 20; give
// the 3xx itself, manual; or make it an Error. C's enum, whose cases are
// words of the program, so each says redirect
enum Redirect { redirectFollow, redirectManual, redirectError }

// a request's method, "" for GET, its headers, sent as written, its body,
// empty for none, and what a redirect does, as JS's RequestInit; a field
// left out of (RequestInit){...} is empty, and its redirect follows
struct RequestInit {
    method: String
    headers: Dictionary<String, String>
    body: Bytes
    redirect: Redirect
}

// what a server answered, after the redirects followed: its status and the
// status's text, ok for 200 to 299, the URL it ended at, the headers, names
// lowercased and repeated ones joined by ", ", and the body as sent
struct Response {
    status: i64
    statusText: String
    ok: bool
    url: String
    redirected: bool
    headers: Dictionary<String, String>
    body: Bytes
}

extend Response {
    // the body as text, or an Error where it is not UTF-8
    let text():Result<String, Error> {
        var s = self.body.string()
        if let err(at) = s {
            var e:Error = {.message = $`fetch: the body is not UTF-8 at byte ${at}`}
            return err(e)
        }
        return s.ok.copy()
    }

    // the body as JSON, JS's res.json() (#484): or an Error where it is
    // not UTF-8, or not JSON, with JSON.parse's message
    let json():Result<JSON, Error> {
        var t = self.text()
        if let err(e) = t {
            return err(e.copy())
        }
        var j = JSON.parse(&t.ok)
        if j.is(error) {
            var e:Error = {.message = $`fetch: the body is not JSON: ${j.error}`}
            return err(e)
        }
        return j
    }
}

// the Response of a request of url as init says: its method, headers and
// body, and what a redirect does
let fetch(url:cstr, init:const RequestInit^):Result<Response, Error> {
    var given = Bytes()                         // the headers as name\0value\0 pairs
    for k, v in init^.headers {
        given += k.cstr
        given += 0
        given += v.cstr
        given += 0
    }
    var status:i64 = 0
    var statusText = $""
    var final = $""
    var redirects:i64 = 0
    var raw = Bytes()
    var body = Bytes()
    var why = $""
    if !kfetch_request(url, init^.method.cstr, &given, &init^.body, init^.redirect as i64, &status, &statusText, &final, &redirects, &raw, &body, &why) {
        var e:Error = {.message = why.copy()}
        return err(e)
    }
    var headers = Dictionary<String, String>()
    var name = $""
    var value = $""
    var i:i64 = 0
    while kfetch_header(&raw, i, &name, &value) {
        if headers.has(name) {
            headers[name] += ", "
            headers[name] += &value
        } else {
            headers[name] = value.copy()
        }
        i += 1
    }
    var res:Response = {.status = status, .statusText = statusText.copy(), .ok = status >= 200 && status <= 299,
                        .url = final.copy(), .redirected = redirects > 0, .headers = headers.copy(), .body = body.copy()}
    return res
}

// a RequestInit written in the call, moved in: fetch(url, (RequestInit){.method = $"POST"})
let fetch(url:cstr, init:RequestInit):Result<Response, Error> { fetch(url, &init) }
let fetch(url:const String^, init:const RequestInit^):Result<Response, Error> { fetch(url^.cstr, init) }
let fetch(url:const String^, init:RequestInit):Result<Response, Error> { fetch(url^.cstr, &init) }

// the Response of a GET of url, following up to 20 redirects
let fetch(url:cstr):Result<Response, Error> {
    var init:RequestInit = {.method = $"GET"}
    return fetch(url, &init)
}

let fetch(url:const String^):Result<Response, Error> { fetch(url^.cstr) }
