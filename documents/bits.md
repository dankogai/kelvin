# Bits: `.bits`

A number's bits, each a `bool` by its place: `x.bits` of an integer and
`b.bits` of a `BigInt`.

## Synopsis

```swift
enum flag { ready, busy, done }               // the flags, by name

let main():int32 {
    var bv:u8 = 0                             // 8 bits, all false
    bv.bits[ready] = true                     // a bit is a bool
    bv.bits[done] = !!1                       // !!n: the bool of 0 or 1
    bv.bits[busy] |= false                    // |=, &= and ~= of a bool
    bv.bits[4].flip()                         // bit 4 flipped
    println(bv, " ", bv.bits[done], " ", bv.bits.count)   // 21 true 8
    let mask:u8 = 0b0110
    println(bv & mask, " ", (bv & mask).bits[2], " ", u8([false, true, true]))   // 4 true 6
    var big = 0n                              // a BigInt: bits of any width
    big.bits[100] = true                      // past its top: it grows
    println(big, " ", big.bits.count, " ", BigInt(big.bits) == big)   // 1267650600228229401496703205376n 102 true
    var flags = $[true, false]                // bools that grow: an Array<bool>
    flags += true
    flags[1].flip()
    println(flags)                            // [true, true, true]
    return 0
}
```

## Description

Kelvin leaves C's bit-fields out. A number's bits are its `.bits`
instead, each a `bool` by its place, 0 the lowest, and an enum names
the flags.

| Kelvin | C |
|--------|---|
| `x.bits[n]` | `(x >> n) & 1` |
| `x.bits[n] = b`, `x.bits[n].flip()` | `x = b ? x \| 1 << n : x & ~(1 << n)`, `x ^= 1 << n` |
| `struct s { flags: u8 }` and an enum of the flags | `struct s { unsigned a : 1, b : 1; }` |

- **An integer's bits** (#530) are `x.bits`, of `i8` to `u128`; see
  [integers.md](integers.md#bits-bits).
  - `x.bits[n]` is bit `n`, read and set where it is, with `=`, `|=`,
    `&=` and `~=` (xor), and a `bool`.
  - `x.bits[n].flip()` flips it.
  - `x.bits` alone is its width of bools, an `Array<bool>`, place 0
    first, and `u8(bools)` the way back: `u8(x.bits) == x`.
  - `n` is 0 to the width less 1, an integer or an enum's value.
- **A `BigInt`'s bits** (#531) are `b.bits`, of any width; see
  [bigint.md](bigint.md#bits-bits).
  - They are two's complement's: past its top, every bit is its sign.
  - `b.bits[n] = true` past its top grows it, so a `BigInt` holds as
    many flags as are set.
  - `b.bits` alone is its shortest form, the last bool its sign, and
    `BigInt(bools)` the way back.
- **Bools that grow** are an `Array<bool>`: `$[true, false]`,
  `flags += b`, `flags[n]`, `flags[n].flip()`, `for b in flags`; see
  [arrays.md](arrays.md).
- **The whole:** `|`, `&`, `~` (xor), the prefix `~`, `<<` and `>>` are
  the integer's own, and a `BigInt`'s; see
  [operators.md](operators.md).
- **`!!n`** (#387) is the `bool` of an integer 0 or 1: `false` of 0,
  `true` of 1.
  - Any other value ends the program, and a literal other than 0 or 1
    is an error.
  - It is no two nots: `!!b` of a `bool` is an error, and two nots are
    written `! !b`.
  - The way back is `i64(b)` or `b.i64`, 0 or 1; see [bool.md](bool.md).
- **A `bool` flips** with `b.flip()`, `b = !b` (#454), and so does a
  bit, `x.bits[n].flip()`.
- **No C bit-field:** `unsigned a : 1` is not Kelvin; a struct holds an
  integer and names its flags with an enum; see
  [versusC.md](versusC.md).
- **`Bits` is no more** (#532). It was a type of its own (#387, #455),
  bits in `u64`s on the heap; the word is now an error that names what
  to write.

  | `Bits`, before #532 | Now |
  |---|---|
  | `Bits(u8(0))`, `bv[n]`, `bv[n] = b` | `var x:u8 = 0`, `x.bits[n]`, `x.bits[n] = b` |
  | `bv.flip(n)`, `bv[n].flip()` | `x.bits[n].flip()` |
  | `Bits(-1, true)`, past 64 bits | a `BigInt`, `b.bits[n] = true` |
  | `Bits([true, false])`, `bv.append(b)` | `u8([true, false])`, `BigInt(bools)`; an `Array<bool>`, `bs += b` |
  | `Bits("0b0110")` | `0b0110`, `0b0110n`, `BigInt("0110", 2)` |
  | `bv \| m`, `~bv`, `bv << n` | the same operators of integers and of `BigInt`s |
  | `bv.count`, `for b in bv` | `x.bits.count`, `for b in x.bits` |
  | `bv.u64s`, `bv.bin` | `x.bin` of an integer, and of a `BigInt` |

## Where it lives

The core, with the prelude's `BigInt`. An integer's bits are C's shifts
and masks, with no call; a `BigInt`'s are modules/BigInt.k's functions,
implied by a program that names `BigInt`.

- **In C:** `x.bits[n]` of a `u8` is a statement expression that checks
  `n` and gives `(bool)((x >> n) & 1)`; `b.bits[n]` is BigInt.k's
  `kv_bi_bit_of(b, n)`, and `!!n` the prelude's `KV_BIT_OF(n)`.

## Properties and methods

| On | Property or method | Gives |
|---|---|---|
| integer | `.bits` | its width of bools, an `Array<bool>`, place 0 first (#530) |
| | `.bits[n]` | bit `n`, a `bool`, set with `=`, `\|=`, `&=` and `~=` (#530) |
| | `.bits[n].flip()` | bit `n` flipped, in the var that holds it (#530) |
| | `u8(bools)`, `i64(bools)`, ... | the integer of a `[bool]`, place 0 first (#530) |
| | `!!n` | the `bool` of 0 or 1; any other ends the program (#387) |
| `BigInt` | `.bits` | its bits in the shortest two's complement form, the last its sign (#531) |
| | `.bits[n]` | bit `n`, past its top the sign; setting there grows it (#531) |
| | `.bits[n].flip()` | bit `n` flipped, in the var that holds it (#531) |
| | `BigInt(bools)` | the BigInt of a `[bool]`, its last bool the sign (#531) |
| `bool` | `.flip()` | `b = !b`, in the var that holds it (#454) |
