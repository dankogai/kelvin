# Pointers: `T^`, `:=`, `any^` and `nullptr`

A pointer is written with a postfix `^`, in its type and when it is
followed, and made with a prefix `&`, as in C. Assigning one is `:=`, so
that a reference and a value never look alike. This document has the
pointer types, `&`, references, `any^` and `nullptr`, and stepping with
`p++`, `.next` and `.prev`; every operator is in
[operators.md](operators.md). Arrays, which C turns
into pointers, are in [arrays.md](arrays.md); walking a pointer with
`for x in p` is in [flow-controls.md](flow-controls.md); `.addr`, `.hex`
and `.isNull` are in [properties.md](properties.md).

## Postfix `^`

- `T^` is a pointer to `T`. `*` only means multiplication.
- C's hardest declarators become readable. A function returning a pointer to
  an array of four ints, `int (*f(void))[4]`, is `let f():[i32](4)^`.

- `p^` is C's `*p`, and `p^.m` is `p->m`: postfix, so it chains left to
  right, and `p^[i]` is `(*p)[i]`. `->` is an error with a hint.

## Prefix `&`

`&x` is the address of `x`, as in C, and the one prefix operator a
pointer needs:

```kelvin
var x:i32 = 1
var p:i32^ := &x          // C: int32_t *p = &x;
let q := &x               // inferred: q is i32^
let k = 42
let r := &k               // const i32^: a let's address points to const
let m := &a[2]            // the rest of an array, or of a cstr (#52)
let f := &twice           // a function's address is the function itself
```

- `&x` of a `let`, or of a let's field or element, points to `const`,
  as a let is `const` in C (#27); `&x` of a `var` points to its type.
- `&a[i]` of an array is a pointer into it, and of a `cstr` the rest of
  the text, a `cstr` (#52). `&f` of a function is `f`, a function
  value, as in C (#31).
- `&` binds as C's prefix operators do, tighter than every binary
  operator and looser than the postfix ones, so `&p^.m` is
  `&(p^.m)` and `&a[i]` is `&(a[i])`; `(&x).hex` needs its parentheses.
- There is no `*`: `*p` is an error that says to write `p^`.

## References: `:=` and `=`

Assigning a pointer (a reference) uses `:=`, and `=` is for values:

```kelvin
var buffer := malloc(8 * 1024):i64^   // declares buffer: i64^
buffer[0] = 42                        // a value, through the reference
var p:i32^ := &x                      // typed declarations too
p := &y                               // reassigning the reference
p^ = 7                                // assigning the value it refers to
for (var n:node^ := list; n != nullptr; n := n^.next) { ... }
```

- `=` on a reference and `:=` on a value are errors, wherever kelvinc can
  see the target's type: variables, parameters, `self`, fields of Kelvin
  structs, `p^` and `a[i]`. Targets it cannot see, such as C typedef
  types, fields of C structs and call results, are not checked
  *(provisional P32)*.
- Pointer arithmetic is unchanged (`p + 1`, `p += 1`, `p - q`), and a
  pointer steps by one element with `p.next` and `p.prev` (#26).
- An array is a value, even an array of pointers:
  `let refs:i32^[2] = [p, q]`. An array parameter, though, is a pointer,
  as in C: in `let f(var a:[i32])`, write `a := a + 1`.
- `:=` is printed as C's `=`. Like `=`, it is a statement (#26), usable
  in a `for` clause and after `let` or `var`.

## No `void`: `any^` and `nullptr`

Kelvin has no `void` type:

- **`any^` is C's `void *`.** `any` exists only behind `^`, so `any^`,
  `any^^` and `const any^` are fine, but `var p:any` is an error.
- **`nullptr` is C's `(void *)0`**, typed `any^`: `p := nullptr`, and
  `var r := nullptr` infers `any^`.
- **A reference declared without a value is `nullptr`**, so `var p:any^`
  means `var p:any^ := nullptr`. This applies to every pointer
  declaration (`var q:i32^`), local or global, but not to `extern` ones
  *(provisional P33)*.
- **A function without a result** omits `: type`, as before.
- **To discard a value**, write it as a statement. There is no `(void)x`,
  and C may warn about an unused value *(provisional P33)*.

`void` is rejected with a hint wherever it is written: `let f():void`,
`var p:void^`, `(void)x`, `x as void`.

## Stepping: `p++`, `p--`, `.next` and `.prev`

- `p++` and `p--` step a pointer by one element, as statements (#51):
  on a line of their own, in a comma list, or in a `for` clause, never
  inside an expression (`p++^` is an error; `*p++` is `p^` then `p++`).
  They are postfix only, and for a `var` pointer kelvinc sees, a field
  or an element too: a `let` pointer, a number, an array, a function
  and `any^` are errors, and so is a `cstr`, which is text, not a
  cursor (#52): take a `var p:u8^ := s` to step. A pointer only C sees,
  as `getenv`'s, steps as C allows *(provisional P63)*.
- `p.next` is `p + 1` and `p.prev` is `p - 1`, a value, for a pointer
  kelvinc can see; `any^` has neither. On anything else, `.next` is a
  field, so a list still walks with `n := n^.next`.

## `.isNull`, `.addr` and `.hex`

`p.isNull` is `p == nullptr`, a `bool` (#50), `p.addr` the address as a
`uintptr_t`, and `p.hex` its text (#37). See
[properties.md](properties.md).
