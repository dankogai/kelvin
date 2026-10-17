# MessagePack: `#import <MsgPack>`

`MsgPack` (#153) packs a `SION` value into MessagePack, https://msgpack.org,
and unpacks bytes into one: the two share a model, nil, bool, an integer,
a double, a string, data, a date, an ext, an array and a map keyed by
any value, so there is no second value type. `MsgPack.pack(&s)` gives a
`Bytes` and `MsgPack.unpack(&b)` a `SION`, as swift-sion's `msgPack` and
`SION(msgPack:)` do.

**Where it lives:** `modules/MsgPack.k`, brought in by `#import <MsgPack>`, which imports `<SION>` ([sion.md](sion.md)); written in Kelvin as functions of the type `MsgPack`, a struct that is their name. Nothing of it is in the prelude or the runtime.

```kelvin
#import <MsgPack>

var s = SION.parse("[\"name\": \"kelvin\", \"n\": 42, \"when\": .Date(0x1p+30)]")
var packed = MsgPack.pack(&s)                 // a Bytes: 83 a4 6e 61 6d 65 ...
var back = MsgPack.unpack(&packed)            // the SION again, or error("...")
println(SION.same(&s, &back))                 // true
```

- **`MsgPack.pack(&s)`** writes each value in its smallest form:
  - `nil`, `true` and `false` as their bytes; an integer as a positive
    or negative fixint, else the smallest of int 8, 16, 32 and 64 that
    holds it; a double as float 64; a string as a fixstr or the
    smallest str; data as the smallest bin; an array and a dictionary
    as the smallest array and map, a dictionary's entries as its keys
    and values in turn.
  - A date as the timestamp extension, type -1: timestamp 64 where the
    seconds are 0 or more and fit 34 bits, with the nanoseconds, else
    timestamp 96.
  - An ext as it is: a `SION.ext` holds an extension's whole encoding,
    its format byte, type and payload, as swift-sion keeps it, so what
    came in goes out unchanged.
  - An `error` is written as its message, a string.
- **`MsgPack.unpack(&b)`** reads every format: fixints, uint 8 to 64 and
  int 8 to 64 as an integer, float 32 and 64 as a double, fixstr and
  str 8 to 32 as a string, bin 8 to 32 as data, fixarray and array 16
  and 32, fixmap and map 16 and 32 as a dictionary, timestamp 32, 64
  and 96 as a date, and fixext 1 to 16 and ext 8 to 32 of any other
  type as an ext holding the whole encoding.
  - It gives the case `error` for bytes that are not MessagePack, the
    unused byte `0xc1`, a value that ends past the bytes, bytes left
    after the value, a string that is not UTF-8, and an uint 64 past
    an `i64`, as swift-sion does.
- **The two agree**: `unpack(&pack(&s))` is the same value as `s` for
  any `SION`, timestamps rounded to nanoseconds.

## Functions

<!-- fragment -->
```kelvin
MsgPack.pack(s: const SION^): Bytes               // the bytes
MsgPack.unpack(b: const Bytes^): SION             // the value, or error(message)
```
