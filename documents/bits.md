# Bits: `Bits`

64 flags in one `u64`, each bit a `bool` by its place.

## Synopsis

```swift
enum flag { ready, busy, done }               // the flags, by name

let main():int32 {
    var bv = Bits()                           // all zeros
    bv[ready] = true                          // a bit is a bool
    bv[done] = !!1                            // !!n: the bool of 0 or 1
    bv[busy] |= false                         // |=, &= and ~= of a bool
    bv.flip(4)                                // bit 4 flipped
    println(bv, " ", bv[done], " ", bv.value) // Bits(0b10101) true 21
    let mask = Bits(0b110)                    // n's bits
    println(bv & mask, " ", bv | mask, " ", bv ~ mask, " ", ~mask == (Bits(-1) ~ mask))   // Bits(0b100) Bits(0b10111) Bits(0b10011) true
    bv <<= 1                                  // as a u64 shifts
    println(bv, " ", bv >> 3, " ", i64(bv[1]))   // Bits(0b101010) Bits(0b101) 1
    return 0
}
```

## Description

`Bits` (#387) is Kelvin's answer to C's bit-fields, which it leaves out:
64 bits in a `u64`, its `.value`, each bit a `bool` by its place, 0 the
lowest. An enum names the flags, and `!!n` makes a bit's `bool` of an
integer 0 or 1.

| Kelvin | C |
|--------|---|
| `Bits` | `kv_bits`, `struct kv_bits { uint64_t value; }` |
| `struct s { a: Bits }` and an enum of the flags | `struct s { unsigned a : 1, b : 1; }` |

- **Making one:** `Bits()` is all zeros, and `Bits(n)` takes an
  integer's bits, as `u64(n)` converts it: `Bits(-1)` is all ones.
  - `n` is an integer of 64 bits or fewer, or an enum's value.
- **Its value:** `bv.value` is the `u64`, read and set:
  `bv.value = 5`, `bv.value += 1`.
- **A bit:** `bv[n]` is bit `n`, a `bool`, 0 the lowest.
  - It is set with `=`, `|=`, `&=` and `~=` (xor), and a `bool`:
    `bv[n] = !!x` of an integer, `bv[n] = x != 0`; an integer is no bit.
  - `bv.flip(n)` flips it.
  - `n` is 0 to 63: a literal past it is an error, and a value past it
    ends the program, as an index past an Array's count does.
  - `n` may be an enum's value, so that the flags have names:
    `bv[busy]`.
- **The whole:** two Bits have `|`, `&`, `~` (xor), `==` and `!=`, and
  one has the prefix `~` and the shifts `<<` and `>>`, as their `u64`s
  do, with `|=`, `&=`, `~=`, `<<=` and `>>=`.
  - A shift is 0 to 63, as a bit's place is; past it the program ends.
  - Other operators are the `u64`'s: `bv.value + 1`.
  - An integer is no Bits: `bv | Bits(1)`, not `bv | 1`.
- **`!!n`** (#387) is the `bool` of an integer 0 or 1: `false` of 0,
  `true` of 1.
  - Any other value ends the program, and a literal other than 0 or 1
    is an error.
  - It is no two nots: `!!b` of a `bool` is an error, and two nots are
    written `! !b`.
  - The way back is `i64(b)` or `b.i64`, 0 or 1; see [bool.md](bool.md).
- **Printing:** `Bits(0b101)`, its value in binary from its highest bit
  that is set, which pastes back; `Bits(0b0)` of all zeros.
- **No C bit-field:** `unsigned a : 1` is not Kelvin; a struct holds a
  `Bits` and names its flags with an enum; see [versusC.md](versusC.md).

## Where it lives

The core. `Bits` is the prelude's `kv_bits`, a struct
of one `uint64_t`, with its bit functions inline in
`kelvin_prelude.h`; its text is `libkelvin`'s, linked without an
import.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| `Bits` | `Bits()`, `Bits(n)` | all zeros; `n`'s bits, as `u64(n)` |
| | `.value` | its `u64`, read and set |
| | `bv[n]` | bit `n`, a `bool`, set with `=`, `\|=`, `&=` and `~=` |
| | `.flip(n)` | bit `n` flipped, in the var that holds it |
| | `\|`, `&`, `~`, `==`, `!=` of two | as of their `u64`s: a Bits, or a `bool` |
| | `~bv`, `bv << n`, `bv >> n` | each bit flipped; shifted by 0 to 63 |
| | `print(bv)`, `.cstr`, `${bv}` | `Bits(0b101)`, which pastes back |
| | `.size`, `.type`, `.typename` | 8; the type; `Bits` |
| integer | `!!n` | the `bool` of 0 or 1; any other ends the program |
