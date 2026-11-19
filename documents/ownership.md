# Ownership: `Bytes`, `String`, `Array<T>`, `Dictionary<K, V>`, `Set<T>`, `Task<T>`, `Iterator<T>`, `BigInt` and `RegExp`

Types that own memory on the heap: a variable owns one, its block
frees it, and `=` never copies it. An owner's name starts with a
capital letter.

## Synopsis

```swift
var b = Bytes("hello, ")            // a variable owns its heap
b += "Kelvin"                       // append: text, a byte, a borrow, a Bytes
var s = $"héllo, κόσμε"             // a String: UTF-8, checked
var xs = $[0, 1, 2, 3]              // an Array<i64>
var ages = ${"ann": 31, "bob": 42}  // a Dictionary<String, i64>
let n = 1n << 100                   // a BigInt
let re = $/l+/g                     // a RegExp
let c = b.copy()                    // = never copies an owner: copy it
let r := &b                         // or borrow it: a pointer
println(r^.count, " ", s.count, " ", xs[3], " ", ages.count, " ", c, " ", n > 1n, " ", s.replace(&re, "L"))   // 13 12 3 2 hello, Kelvin true héLo, κόσμε
```

## Description

Kelvin used no heap of its own until #54. A type that does is an
*owner*: a variable owns its heap, and the variable's block frees it.
The rules below are what kelvinc enforces, from what it sees; a copy of
the struct through C is C's business, and harmless, since an owner is
never copied implicitly.

### An owner's name starts with a capital

**A type of Kelvin's that owns is named with a capital first letter:**
`String`, `Bytes`, `Array<T>`, `BigInt`, `RegExp`.

- **A name in lower case never owns:** `i64`, `f64`, `bool`, `cstr`,
  `c64`, `rat64`.
  - `=` copies it, a function takes a copy of it, and nothing is freed.
- **So the name says what `=` does.**
  - `var q = r` of a `rat64` is a copy.
  - `var q = r` of a `BigRat` is an error that says to write
    `r.copy()`, or to borrow it, `:= &r`.
- **A module's types keep to it:** `IO` of `<IO>`, `JSON` of `<JSON>`,
  `BigRat` of `<Rational>`, `BigFloat` of `<BigNum>`.
- **A capital alone does not say it owns.**
  - `Range<T>` is a value, and so is a `Stat`.
  - `Optional<T>` and `Result<T, E>` own what they hold: an `i64?` is
    a value, a `String?` an owner.
- **A struct of a program's own owns where a member does** (O7),
  whatever it is named.

### The prelude's owners

Each is in every program, with no import, and its own document says
how it is made, read and changed.

| Type | What it is | Its document |
|---|---|---|
| `Bytes` | any bytes, growing (#54) | [bytes.md](bytes.md) |
| `String` | Unicode text, UTF-8 in a `Bytes` (#55) | [strings.md](strings.md) |
| `Array<T>`, `$[T]` | a growable array of any value type (#57) | [arrays.md](arrays.md#arrayt-a-growable-array-on-the-heap) |
| `Dictionary<K, V>`, `${K: V}` | a hash map, in the order added (#65) | [dictionaries.md](dictionaries.md) |
| `Set<T>`, `${T}` | a hash set, a Dictionary with no values (#71) | [sets.md](sets.md) |
| `Task<T>` | what `async f(x)` gives: a call on a thread of its own, and its value (#312) | [tasks.md](tasks.md) |
| `Iterator<T>` | a state and a function of it (#325) | [iterators.md](iterators.md#iteratort-a-state-and-a-function) |
| `BigInt` | an integer of any size, `123n` (#507) | [bigint.md](bigint.md) |
| `RegExp` | a regular expression, `$/.../` (#157, #504) | [regexp.md](regexp.md) |

- **An owner holds owners:** an `Array<String>`, a Dictionary's
  values, a `BigInt`'s limbs, an `Array<u64>`.
  - What holds them frees them, and `.copy()` copies them.
- **A module's owner follows the same rules:** an `IO` is closed when
  its block ends, as a `Bytes` is freed ([io.md](io.md)).

### When a check fails

A check that fails at run time, an index past the count, text that is
not UTF-8, a pattern that is not one, prints its reason on stderr,
`kelvin: index 3 is out of range: the Bytes has 3`, and the program
exits with status 1 (#174); stdout is flushed first, so what was
printed stays. With `KELVIN_ABORT=1` in the environment it aborts
instead, for a debugger or a core. A test of such a failure writes its
status as `// exit: 1` and the message as `// err:` lines.

## Where it lives

The prelude. The owners are `kelvin_prelude.h`'s types and `libkelvin`'s functions, linked without an import; the rules are kelvinc's, which writes the frees.

## The rules

| | Rule |
|---|------|
| **O1** | **A `Bytes` owns its heap**, and so does a struct that holds one. |
| **O2** | **A variable owns it, and its block frees it.** When the block ends, by its `}`, a `return`, a `break` or a `goto` out of it, the owner is freed: C's `cleanup` attribute, which gcc and clang have, and which rejects a `goto` into the block past the owner. A global owner lives for the program, freed at its exit by a function `main` registers, or a module as it is loaded (#178, #491); declared with its type alone, `var journal:String`, it starts empty, and with a value, `var names = $["a"]`, it is given that value at its first use, once, as C initializes a global with a constant alone (#493); assigned anew, what it held is freed, as a local's is (#493). A `let` owner cannot change. |
| **O3** | **An owner is never copied by `=`.** `var c = b` and `c = b` are errors with two hints: `b.copy()` for a copy of the bytes, `:= &b` for a borrow. The same holds for a member of a struct, in an initializer list too: `(T){p.name}` is an error. A local owner named in a struct's literal moves into it, as into a call (#503): `(Big){r, false}`, `let b:Big = {r}` and `return {.limbs = r}` take `r`, which is dead until assigned anew; a global, a lent operand and an element of a `for` are copied, `g.copy()`. |
| **O4** | **`return b` moves.** The caller owns it; the callee's variable is empty when it is freed. `return c ? a : b` moves whichever arm it gives, as `return a` or `return b` would (#203). A `Bytes` a function gives is bound (`let b = f()`), assigned (`b = f()`), returned, passed, or dropped as a statement, which frees it at once; used otherwise (`f().count`) it is an error that says to bind it. |
| **O5** | **Passing by value moves.** `take(b)` with `let take(d:Bytes)` hands the heap to `d`, which the callee's block frees; afterwards `b` is dead for the rest of its block, and using it is an error, until `b = Bytes()` or another value is assigned. kelvinc keeps it by the path that moved it (#605): the branches of an `if` and the cases of a `switch` are not both run, so an owner one of them moved is whole in the other, `if c { take(b) } else { take(b) }`; after them it is dead where any of them that goes on moved it; and a block that ends in a `return` goes on nowhere, so `if c { return b }` leaves `b` for what follows. A loop is not followed: a move in its body counts after it. It was one list for every path before, and each of those was refused. A global owner does not move. A member, `take(v.b)`, does not move alone: pass a borrow or a copy. A method's parameter and a call through a function value, `f(b)` with `f:(Bytes):int64`, move an owner the same way (#158). An owner that moves out in an expression is named nowhere else in it (#500), as C evaluates arguments and operands in an order it leaves open: `f(b, b)`, `f(b, b.count)` and `b.count + f(b)` are errors, which say to copy or read it in a statement before; `f(b.copy(), b)` is one too. The target of `=` is given anew, so `b = f(b)` and `z += w` stay. An operator is lent an owner operand, which its caller keeps (#501): `c + c` and `a * a + b` move nothing; so is a parameter written `b:lent T` (#510), `let total(a:lent bag, b:lent bag)`. |
| **O6** | **A borrow is a pointer**, `let r := &b`, a `Bytes^`, with the rules text has (#39, #44): a borrow of a local owner may not be returned, or assigned to a variable of an outer block. Through a borrow of a var, the methods that change it work: `r^.append("x")`. A function reads an owner through `d:const Bytes^`, changes it through `d:Bytes^` and takes it through `d:Bytes`. A let's borrow is a `const T^`, read-only (#273). |
| **O7** | **A struct that holds an owner owns it.** `struct msg { body: Bytes }` gets a derived `_kv_msg_free`, as it gets a derived `.cstr`; a local of that type is freed at its block's end, and O3 to O5 apply to it. Assigning to a member, an element or through a pointer, `m.body = Bytes("x")`, frees what it held, after the new value is made (#134). An array member of owners is freed too. A union may not hold an owner, and an array of owners as a variable waits for its own change. |
| **O8** | **C sees pointers, not owners.** Passing a `Bytes` by value to a function kelvinc cannot see (a C function) is an error: pass `b.at` and `b.count`, or `b.cstr`. `print` and `println` take one. |
| **O9** | **Failure ends the program.** Out of memory, and an index out of range, print the reason and exit with status 1 (#174); `KELVIN_ABORT=1` in the environment aborts instead, for a debugger. |
| **O10** | **The C stays small.** `--emit-c` shows ordinary C: `__attribute__((cleanup(kv_bytes_free))) kv_bytes b = ...`, `kv_bytes_take(&b)` where it moves, `kv_bytes_assign(&b, v)` where it takes a value, and a `_kv_T_free` for a struct that owns. |
| **O11** | **An owner an expression gives is held where it is used** (#187). `$"a b".split(re)`, `make().name`, `println(make())`, `$"a" == s`, `parse("1") ?? 0` and `for x in rows() { }` keep it in a hidden local until the expression, the comparison or the loop is done, then free it; a member that owns is copied out, and one given where a borrow is taken, `s.split($/\s+/)`, is lent. A pointer into it keeps it alive until the call or expression around the pointer is done, up to the whole statement (#245): `strlen($"abc".cstr)` and `println(String(42).cstr)` work, and so does a call whose result only C sees, which may be a pointer, `strlen(strchr($"xyz".cstr, 'y'))` (#437); in an arm of `?:`, or right of `&&`, `||` or `??`, which are not always evaluated, it is held there alone (#437). A pointer that would outlive the statement, `let p := make().name.cstr`, would dangle, and a change to it, `rows().append(3)`, would be lost: both are errors, which say to bind it first. |
| **O12** | **`c ? a : b` of owners is what its arms are** (#203). Two places, `c ? s : t`, are a place: read where they are, `println(c ? s : t)`, not copied by `=` (O3) nor moved into a call (O5), as `s` alone would not be. A place and a value an expression gives, `c ? s : make()`, would free one and not the other, so it is an error but where it is returned (O4): copy the place, `s.copy()`, or choose with `if`. |

```swift
let greeting(name:cstr):Bytes {      // the caller owns the result
    var b = Bytes("hello, ")
    b += name
    return b                         // moves out
}
let total(data:Bytes):int64 {          // data moves in, and is freed here
    var n = 0
    for x in data { n += int64(x) }
    return n
}
let longest(a:Bytes^, b:Bytes^):Bytes^ { a^.count >= b^.count ? a : b }   // borrows
```

A struct, or an enum with values (#61), that holds an owner is an owner
under the same rules, copied with `.copy()`, and may be an element of an
`Array<T>`.

Not yet: a fixed array of owners as a variable (`[Bytes](4)`; an
`Array<Bytes>` grows), `insert` and `remove` on a `String`, slices that
borrow rather than copy, and sharing one owner from two places, which
would be an explicit type of its own if it is ever needed.
