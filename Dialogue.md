

### 145. A JSON module

> Add JSON handler as an importable module as `#import <JSON>`.
>
> * define `union JSON` like `enum SION` in https://github.com/dankogai/swift-sion
>    * bool, f64, String, Array<JSON> or Dictionary<String, JSON>.  is nullptr fit for null of JSON?
> * `JSON.parse(str)` takes `cstr` or `String` and return `JSON`.
> * `JSON.stringifiy(json, replacer, space)` like JS.  space is either cstr or String.

**Claude** found the pieces mostly there: an enum with values holds an
Array and a Dictionary of itself, and `null` is a case carrying
nothing, not `nullptr`, a pointer. Two things the core lacked: a
function called by a type's name, and `#import <JSON>` without `.k`.
Asked, the user chose Swift's spelling for the first, `static let
T.name(...)`, and a case `error: String` for a text that is not JSON.
So three changes: #111 functions of a type, #112 bare module names,
and #113 `modules/JSON.k`, with `JSON.parse` of a cstr or a borrowed
String and `JSON.stringify(&j, replacer, space)` as JS has them,
numbers written as JS writes them. Details are provisional P123, P124
and P125.

There are 659 tests, and all pass with clang and with gcc 15.
