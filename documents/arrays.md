# Arrays: `[T]`, `[T](N)` and `.count`

An array type is written in brackets, as Swift writes it, and its count
is a property. A fixed array lives where it is declared; one that grows
is `Array<T>`, on the heap, in [ownership.md](ownership.md). This document has the types, the `[...]` initializers,
`[T](n)` for a zero-filled array, `.count` and `.size`, and what stays
C's: an array passed to a function is a pointer. Byte arrays that hold
text are in [cstrings.md](cstrings.md).

## The types

- `[T]` is an array of `T`, as Swift writes it, and `[T](N)` one of N
  elements (#49): `[i32^](4)` is an array of four pointers, `[i32](4)^` a
  pointer to an array of four, and `[[i32](3)](2)` C's `int32_t m[2][3]`,
  indexed as `m[1][2]`. A declaration with a value needs no count:
  `let a:[i32] = [1, 2, 3]`, or just `let a = [1, 2, 3]`, has three;
  `[T](n)` is a value too, n zero-filled elements, with a count C computes
  at run time if need be (C's VLA, in a `var`). A count never changes:
  `.count` is it, and `.size` the bytes, `count * sizeof(T)`. A `var`
  array's elements may change, a `let` array's may not. An array passed
  to a function is a pointer, as in C, so `.count` there is an error:
  pass the count beside it *(provisional P61)*.

```kelvin
var a:[i32](4)                  // C: int32_t a[4]
var m:[[i32](3)](2)             // C: int32_t m[2][3], indexed m[1][2]
var ps:[i32^](4)                // C: int32_t *ps[4], four pointers
let q:[i32](4)^ := &a           // C: int32_t (*const q)[4]
let names:[cstr] = ["ab", "cd"] // the count, 2, comes from the value
struct bag { n: i64; xs: [i64](3) }
```

- `[[T]]` with a value counts every dimension: the outer from the rows,
  the inner from the first row, which every row must match, since C
  needs one inner count. `var m:[[i64]] = [[1, 2, 3], [4, 5, 6]]` is
  `[[i64](3)](2)`; a row that is a string gives no count, so write it,
  `[[u8](3)]`.
- A qualifier is the elements', inside the brackets: `[const u8]`.
- Suffixes still read left to right after the brackets: `[T](N)^` is a
  pointer to the array, `[T^](N)` an array of pointers.
- `T[N]` and `T[]` are errors whose hint spells the type the new way.

## Initializers: `[...]`

An array is initialized with `[...]`, and a struct or union keeps
`{...}` (#48), nested too:

```kelvin
let a:[i32](3) = [1, 2, 3]
let b = [1, 2, 3]                       // [i64](3), inferred
let m = [[1, 2], [3, 4]]                // [[i64](2)](2)
var g:bag = {1, [7, 8, 9]}              // an array inside a struct
let h:[point](2) = [{1, 2}, {3, 4}]     // structs inside an array
let sp:[i64](4) = [[2] = 9, [0] = 1]    // C's designators: [2] = 9
let s:[u8] = "hi"                       // a string fills a byte array
```

- Where kelvinc sees the type, `{...}` for an array and `[...]` for a
  struct are errors with a hint. Where only C sees it (a C struct's
  member, a typedef), either is accepted, as both are C's `{ }`.
- An item that starts with `[` is a nested array unless `=` follows
  it, which makes it a designator.
- an array literal whose items are all of one inferred type is an array
  of them (#48): `let a = [1, 2, 3]` is `[i64](3)`, `[1.5, 2.0]` is
  `[f64](2)`, `[[1, 2], [3, 4]]` is `[[i64](2)](2)`, and `[p, q]` of two
  points is `[point](2)`; so is `[T](n)`, and an array's compound literal
  declares the array itself (#49)

## `[T](n)`: a zero-filled array

`[T](n)` is a value: n elements, all zero. The count may be a constant
or, for a local `var`, a value C computes at run time (C's variable
length array, declared and then zeroed with `memset`):

```kelvin
var z = [u8](256)              // uint8_t z[256] = {0}
var line = [u8](n)             // uint8_t line[n]; memset(line, 0, sizeof line)
let t = [f64](3)               // a let of a constant count is fine
```

A `let` of a count computed at run time is an error, since C cannot fill
a `const` array after declaring it.

## `.count` and `.size`

`a.count` is the number of elements, set when the array is made and
never changed; `a.size` is the bytes, `a.count * sizeof(T)`. Both hold
for a variable length array, since `sizeof` is computed at run time
there. A `var` array's elements may change; a `let` array's may not.

```kelvin
for i in 0..<a.count { a[i] = a[i] * 2 }
```

## Arrays and pointers

Kelvin prefers arrays to pointers where it can, but an array is C's:

- **A parameter `a:[i64]`** is a pointer in C, so `a.count` there is an
  error: pass the count beside the array, `let sum(a:[i64], n:i64)`. A
  `let` parameter written with a count, `xs:[i32](4)`, is walked by
  `for x in xs` up to that count.
- **`var p := a`** is the pointer C makes of the array, and `p^` is
  `a[0]`. A declaration without a type does the same: `let ap := arr` is
  a pointer, since C does not copy an array into a variable.
- **A compound literal** of an array, `([i32])[10, 20, 30]`, declares
  the array itself in `let c = ([i32])[10, 20, 30]`, and is a pointer
  where one is declared (`let q:i32^ := ([i32])[1, 2]`).
Compound literals are not casts, and they work as in C for any type,
including typedef names with suffixes, and under `sizeof`:
`(point){.y = 7}`, `(div_t){.quot = 3, .rem = 1}`. An array's takes
`[...]` (#48), and `[T]` counts its items: `([size_t])[1, 2]`,
`sizeof ([i32])[1, 2, 3]` is 12, `for x in ([i32])[5, 6, 7] { }`
*(provisional P19, P60)*.

- **A list is not a value:** where C expects a value, as for
  `memcpy(buf, ['a', 'b'], 2)` or `show([1, 2])`, write a compound
  literal, `([u8])['a', 'b']`. kelvinc says so, rather than taking the
  list for a function.
- **`.cstr`**: arrays have none, since C arrays are not values; index
  them, or put them in a struct, whose text shows them as `[a, b]`.
- **`.isNull`**, `.addr` and `.hex` are not for arrays, which are never
  null: write `(&a[0]).addr`.
- **An array of functions**, or a pointer to a function type, has no
  spelling yet.
- **`Array(a)`** copies a fixed array into a growable one, and
  `Array([1, 2, 3])` makes one of the elements written, and
  `Array([[1], [2, 3]])` an Array of Arrays (#57, #58); `$[1, 2, 3]` is
  the value and `$[i64]` the type, for short (#62, #64).

## `Array<T>`: a growable array on the heap

A fixed array lives where it is declared and never grows. `Array<T>`,
or `$[T]` for short, is a growable array on the heap (#57), an owner:
freed when its block ends, moved by `return` and by passing, copied
only by `.copy()`, borrowed as a pointer. The rules are in
[ownership.md](ownership.md); this is the summary.

```kelvin
var xs = $[1, 2, 3]              // Array<i64>, from the elements; Array<i64>() is empty
xs += 4                          // append; also xs.append(4)
xs += &ys                        // ys's elements, copied; xs += make() moves an Array in
xs.insert(0, 100); xs.remove(1, 2); let last = xs.pop()
println(xs.count, " ", xs[0], " ", xs.capacity)   // xs[i] is checked: out of range ends the program
for x in xs { }                  // each element, a let
var m:$[[i64]] = $[[1, 0], [0, 1]]   // Arrays of Arrays; of Strings, Bytes, Dictionaries, structs that own
let ys = Array(fixed)            // a copy of a fixed array; Array(&xs) a copy of an Array
```

- **Making one:** `$[a, b, c]` or `Array([a, b, c])` with `T` inferred
  from the elements, `Array<T>()`, `Array<T>(n)` of n zero elements,
  `Array(a)` of a fixed array, `Array(&other)` a copy; a declaration
  without a value is empty.
- **Methods:** `append` (also `+=`), `insert`, `remove`, `pop`, `clear`,
  `reserve`, `compact`, `copy`; **properties** `count`, `capacity`, `at`
  (the elements as a `T^`), `size`, `typename`.
- **Elements** are any value type, owners included, which the Array
  then owns: a `Bytes`, a `String`, an `Array`, a `Dictionary`, a struct
  or an enum with values that owns. A fixed array is not an element.
- **Not yet:** text (`print(xs)` is an error: show the elements), `==`,
  sorting and searching.

