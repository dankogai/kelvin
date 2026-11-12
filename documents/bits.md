# Bits: `Bits`

Bits on the heap, as many as it holds, each a `bool` by its place.

## Synopsis

```swift
enum flag { ready, busy, done }               // the flags, by name

let main():int32 {
    var bv = Bits(u8(0))                      // 8 bits, all false
    bv[ready] = true                          // a bit is a bool
    bv[done] = !!1                            // !!n: the bool of 0 or 1
    bv[busy] |= false                         // |=, &= and ~= of a bool
    bv.flip(4)                                // bit 4 flipped
    bv[5].flip()                              // and bit 5
    println(bv, " ", bv[done], " ", bv.count) // Bits("0b00110101") true 8
    let mask = Bits("0b0110")                 // text, its last digit place 0
    println(bv & mask, " ", mask | Bits([true]), " ", ~mask)   // Bits("0b00000100") Bits("0b0111") Bits("0b1001")
    var big = Bits(-1, true)                  // an i64's 64 bits, then one more
    big.append([false, true])                 // and two more
    big <<= 1                                 // a false bit at place 0: 68 bits
    println(big.count, " ", big.u64s, " ", big.bin)   // 68 [18446744073709551614, 11] ["0b1111111111111111111111111111111111111111111111111111111111111110", "0b1011"]
    return 0
}
```

## Description

`Bits` (#387, #455) is Kelvin's answer to C's bit-fields, which it leaves
out, and a vector of bits: its bits live in `u64`s on the heap, each a
`bool` by its place, 0 the lowest bit of the first `u64`. It grows as an
`Array` does, and it is an owner, as a `Bytes` is: a variable owns it,
assigning moves it, `.copy()` copies it, and its block frees it; see
[ownership.md](ownership.md). An enum names the flags, and `!!n` makes a
bit's `bool` of an integer 0 or 1.

| Kelvin | C |
|--------|---|
| `Bits` | `kv_bits`, `struct kv_bits { uint64_t *at; size_t count, cap; }` |
| `struct s { a: Bits }` and an enum of the flags | `struct s { unsigned a : 1, b : 1; }` |

- **Making one:** `Bits()` is empty, its count 0.
  - `Bits(a, b, ...)` takes, in turn from place 0, bools, `[bool]`s,
    integers and text, each appended as `.append` appends it.
  - A `bool` is one bit; a `[bool]`, written `[true, false]` or a
    fixed array or an `Array<bool>`, its bools, its first at the lowest
    place.
  - An integer is its type's width of bits, its lowest first: a `u8`'s
    8, an `i32`'s 32, and a literal's 64, as a literal is an `i64`.
    `Bits(0)` is 64 bits, all false, and `Bits(-1)` 64 bits, all true.
  - Text is `0b` and binary digits, as a binary literal is written:
    `Bits("0b0110")` is 4 bits, its last digit place 0. A literal is
    checked; a `cstr` or a `String` that is no such text ends the
    program.
- **A bit:** `bv[n]` is bit `n`, a `bool`, 0 the lowest.
  - It is set with `=`, `|=`, `&=` and `~=` (xor), and a `bool`:
    `bv[n] = !!x` of an integer, `bv[n] = x != 0`; an integer is no bit.
  - `bv.flip(n)` flips it, and so does `bv[n].flip()` (#454), as a
    `bool`'s `b.flip()`.
  - `n` is 0 to the count less 1: a negative literal is an error, and a
    place past the count ends the program, as an index past an Array's
    count does.
  - `n` may be an enum's value, so that the flags have names:
    `bv[busy]`.
- **Growing:** `bv.append(x)` appends what `Bits(x)` would make: a
  `bool`, a `[bool]`, an integer or text.
  - `bv.capacity(n)` makes room for `n` bits, rounded up to a multiple
    of 64; it never shrinks. `bv.capacity` reads it.
  - `bv.count` is the bits it has, and `bv.isEmpty` whether it has
    none.
- **The whole:** two Bits have `|`, `&`, `~` (xor), `==` and `!=`, and
  one has the prefix `~`, with `|=`, `&=`, `~=`, `<<=` and `>>=`.
  - `|`, `&` and `~` of two counts give the longer, the shorter's
    missing bits false, as integers of two widths are widened.
  - `~bv` flips each of its count bits.
  - `bv << n` puts `n` false bits at place 0, so the count grows by
    `n`; `bv >> n` drops its `n` lowest bits, so the count shrinks by
    `n`, to none. A negative shift ends the program.
  - `==` is of the same count and the same bits.
  - An integer is no Bits: `bv | Bits(1)`, not `bv | 1`.
- **Its u64s:** `bv.u64s` is an `Array<u64>` of a copy of them, place 0
  in the lowest bit of the first; the bits past the count are 0.
  - `bv.bin` is an `Array<String>`, one `"0b..."` per `u64`, its
    highest bit first: 64 digits, and the last its bits that remain.
  - `.value`, the one `u64` of #387, is gone with #455: it is an error
    that names `.u64s`.
- **Walking it:** `for b in bv` walks its bits, each a `bool`, place 0
  first, as a `[bool]` is walked; a Bits an expression gives is bound to
  a variable first.
- **`!!n`** (#387) is the `bool` of an integer 0 or 1: `false` of 0,
  `true` of 1.
  - Any other value ends the program, and a literal other than 0 or 1
    is an error.
  - It is no two nots: `!!b` of a `bool` is an error, and two nots are
    written `! !b`.
  - The way back is `i64(b)` or `b.i64`, 0 or 1; see [bool.md](bool.md).
- **Printing:** `Bits("0b0101")`, each bit a digit, its highest place
  first, which pastes back with its count; `Bits()` of none.
  - `.cstr`, and a Bits in a struct's text, is cut at 63 bytes, ending
    in `...`, as a string in a struct's text is; a template's is cut as
    a string's is; `print` shows it whole.
- **No C bit-field:** `unsigned a : 1` is not Kelvin; a struct holds a
  `Bits` and names its flags with an enum; see [versusC.md](versusC.md).
- **An integer's bits** are `x.bits`, an `Array<bool>`, `x.bits[n]` and
  `x.bits[n].flip()` (#530); see [integers.md](integers.md).
- **A `BigInt`'s** are the same, of any width (#531): `b.bits[n] = true`
  past its top grows it; see [bigint.md](bigint.md#bits-bits).

## Where it lives

The core. `Bits` is the prelude's `kv_bits`, `u64`s on the heap with
their count in bits and their room in `u64`s; its functions are
`libkelvin`'s, runtime/bits.c, linked without an import.

- **In C:** `Bits(u8(0))` is `({ kv_bits _kv_bm = kv_bits_new(); ...
  kv_bits_push_int(&_kv_bm, ...); _kv_bm; })`; `bv[n]` is
  `kv_bits_at(&(bv), (int64_t)(n))`, and `bv | m`
  `kv_bits_op(&(bv), &(m), '|')`, a new Bits. A Bits an expression
  gives, read by an operator, is held in a C temporary that frees it.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Bits` | `Bits()`, `Bits(a, b, ...)` | empty; of bools, `[bool]`s, integers and text `"0b..."`, in turn from place 0 (#455) |
| | `bv[n]` | bit `n`, a `bool`, set with `=`, `\|=`, `&=` and `~=` |
| | `.flip(n)`, `bv[n].flip()` | bit `n` flipped, in the var that holds it; the second #454's |
| | `.append(x)` | `x` appended, a `bool`, a `[bool]`, an integer or text (#455) |
| | `.capacity(n)`, `.capacity` | room for `n` bits, a multiple of 64; the room, in bits (#455) |
| | `.count`, `.isEmpty` | the bits it has, a `u64`; whether it has none (#455) |
| | `.u64s` | its `u64`s, an `Array<u64>` (#455) |
| | `.bin` | each `u64`'s `"0b..."`, an `Array<String>` (#455) |
| | `.copy()` | a copy, a new owner (#455) |
| | `\|`, `&`, `~`, `==`, `!=` of two | a Bits of the longer count, or a `bool` |
| | `~bv`, `bv << n`, `bv >> n` | each bit flipped; `n` false bits put at place 0, or the `n` lowest dropped |
| | `for b in bv` | each bit, a `bool`, place 0 first (#455) |
| | `print(bv)`, `.cstr`, `${bv}` | `Bits("0b0101")`, which pastes back |
| | `.size`, `.type`, `.typename` | 24, `sizeof(kv_bits)`; the type; `Bits` |
| integer | `!!n` | the `bool` of 0 or 1; any other ends the program |
