# fetch: `#import <fetch>`

JS's `fetch(url)` as a GET over HTTP and HTTPS, giving a `Result<Response, Error>`.

## Synopsis

```swift
#import <fetch>

let main():int32 {
    var r = fetch("https://example.com/")
    if let res = r {
        println(res.status, " ", res.statusText, " ", res.ok)   // 200 OK true
        println(res.url, " ", res.redirected)                     // https://example.com/ false
        println(res.headers["content-type"])                      // some("text/html; charset=utf-8")
        var text = res.text() ?? $"(not UTF-8)"
        println(text.count, " ", res.body.count)
    } else {
        println(r.err.message)          // fetch: cannot find the host ..., and the like
    }
    return 0
}
```

## Description

`#import <fetch>` (#482) brings in `fetch(url)`, JS's fetch as a GET:
it asks for the URL, follows redirects, and gives what the server
answered, a `Response`, or what went wrong, an `Error`, as a
`Result<Response, Error>` that the caller faces before reading on.

- **`fetch(url)`** takes text, a `cstr`, or a String by reference,
  `fetch(&s)`, of an `http://` or `https://` URL.
  - It waits for the whole answer: there is no Promise. For one on a
    thread of its own, `async` a function that takes the String moved
    in, and `await` it, as [tasks.md](tasks.md) has it; two such
    fetches run at once:
    `let get(url:String):Result<Response, Error> { fetch(&url) }`, then
    `var t = async get($"https://example.com/")` and `var r = await t`.
    - `async fetch(url)` itself would share the text of a `cstr` with
      the thread, which kelvinc refuses.
  - A `#fragment` is not sent, as a browser does not send it.
  - Redirects, 301, 302, 303, 307 and 308, are followed up to 20, as
    JS's are; a Location may be absolute, from the root, or relative,
    with `.` and `..` taken out.
  - The request says `Connection: close`, `Accept: */*`,
    `Accept-Encoding: identity`, so the body comes as it is, and
    `User-Agent: Kelvin-fetch`.
- **A `Response`** is a struct that owns its parts:
  - `status`, an `i64`, and `statusText`, the status line's text, as
    `404` and `Not Found`; `ok` is whether the status is 200 to 299.
  - `url` is the URL it ended at, after the redirects, and `redirected`
    whether there were any.
  - `headers` is a `Dictionary<String, String>`, its names lowercased,
    as JS's `Headers` reads them: `res.headers["content-type"]` is an
    Optional, `none` where there is no such header.
    - A header that comes more than once is one entry, its values joined
      by `", "`.
    - Text that is not UTF-8, as old servers send, is read as Latin-1.
  - `body` is a `Bytes`, the body as sent: its `Content-Length`, its
    chunks, or all until the connection closes.
  - `res.text()` is the body as a String, or an `Error` where it is not
    UTF-8, as `b.string()` is for a Bytes.
- **An `Error`** is `{message: "..."}`, a struct with a `message`, a
  String that names what went wrong and where:
  - a URL that is not `http://` or `https://`, has a user, a port out of
    1 to 65535, no host, or a space;
  - a host not found, a connection refused, no answer in 60 seconds;
  - a certificate not trusted, or TLS that fails;
  - an answer that is not HTTP/1.1, a body cut short;
  - more than 20 redirects;
  - HTTPS where it is not built in.
  - A status of 404 or 500 is no Error: it is a Response, whose `ok` is
    false, as JS has it.
- **HTTPS** is OpenSSL's, where Kelvin was built with `HAS_SSL=1`, the
  default.
  - The certificate is checked against the system's trusted ones, as
    OpenSSL finds them; `SSL_CERT_FILE` or `SSL_CERT_DIR` in the
    environment names others, as for a test's own.
  - It must be for the host in the URL, a name or an address, and TLS
    is 1.2 or later.
  - Built with `HAS_SSL=0`, an `https://` URL is an Error that says so;
    `http://` works as ever.
- **Building it:** `make` finds OpenSSL with tools/ssl-flags.sh, by
  pkg-config, Homebrew's `openssl@3`, MacPorts', `/usr/local` or the
  system's, and stops where it finds none.
  - `make HAS_SSL=0`, or `HAS_SSL=0` in the environment, builds without
    HTTPS; `SSL_CFLAGS` and `SSL_LIBS` say where OpenSSL is.
  - Changing it builds `libkfetch` again.
- **Not here yet:** a method other than GET, a request's headers or
  body, and `res.json()`, which wait for `fetch(url, init)`.

## Where it lives

`modules/fetch.k`, written in Kelvin over `libkfetch`, runtime/fetch.c,
an HTTP/1.1 client of its own over sockets, with OpenSSL under it for
HTTPS; `make` builds the header and the library with `kelvinc --lib`,
and writes `modules/libkfetch.link`, the flags OpenSSL needs, which
kelvinc adds to the link of a program that imports `<fetch>`.
tests/fetch.sh tests it against a server of its own on 127.0.0.1,
tests/fetch/server.py, HTTPS with a certificate made for the test.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| — | `fetch(url)` | a `Result<Response, Error>`: a GET of `url`, a `cstr` or `&s` of a String, following redirects |
| `Response` | `.status` | the status, an `i64` |
| | `.statusText` | the status line's text, a String |
| | `.ok` | whether the status is 200 to 299 |
| | `.url` | the URL it ended at, a String |
| | `.redirected` | whether a redirect was followed |
| | `.headers` | a `Dictionary<String, String>`, names lowercased, repeats joined by `", "` |
| | `.body` | the body, a `Bytes` |
| | `.text()` | the body as a String, or an `Error` where it is not UTF-8: a `Result<String, Error>` |
| `Error` | `.message` | what went wrong, a String |
