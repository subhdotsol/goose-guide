# Goose Syntax: The Complete Cheat Sheet

Every piece of Goose syntax implemented so far, on one page, each with a short
example. This is a condensed version of `docs/reference.md` (about 4,000
lines) and `docs/tutorial.md`. For the exact rules, see `docs/goose_spec.md`.

Run any snippet by wrapping it in `fn main() { ... }` and running
`build/goose file.goose`.

---

## Table of contents

1. [Program skeleton](#1-program-skeleton)
2. [Comments, identifiers, keywords](#2-comments-identifiers-keywords)
3. [Literals](#3-literals)
4. [Variables: let, var, const](#4-variables-let-var-const)
5. [Types at a glance](#5-types-at-a-glance)
6. [Scalars, arithmetic, operators](#6-scalars-arithmetic-operators)
7. [Casts and conversions](#7-casts-and-conversions)
8. [Arrays](#8-arrays)
9. [Strings and printing](#9-strings-and-printing)
10. [Slices](#10-slices)
11. [Structs](#11-structs)
12. [Enums and match](#12-enums-and-match)
13. [References and optionals](#13-references-and-optionals)
14. [Relative references](#14-relative-references)
15. [Control flow](#15-control-flow)
16. [Loops](#16-loops)
17. [Functions](#17-functions)
18. [Generics, function values, blocks](#18-generics-function-values-blocks)
19. [Recursion](#19-recursion)
20. [Errors: return … from, assert, abort](#20-errors-return--from-assert-abort)
21. [Pools: reusable and reusable[]](#21-pools-reusable-and-reusable)
22. [Index types and checkfree](#22-index-types-and-checkfree)
23. [const for (compile-time expansion)](#23-const-for-compile-time-expansion)
24. [Modules, packages, namespaces, globals](#24-modules-packages-namespaces-globals)
25. [Threads](#25-threads)
26. [Serialization](#26-serialization)
27. [Calling C / being called from C](#27-calling-c--being-called-from-c)
28. [Function qualifiers](#28-function-qualifiers)
29. [Builtins and array members](#29-builtins-and-array-members)
30. [Operator precedence](#30-operator-precedence)
31. [Standard library quick list](#31-standard-library-quick-list)
32. [What Goose does NOT have](#32-what-goose-does-not-have)

---

## 1. Program skeleton

```goose
import std;                      // stdlib modules are imported by name

struct Point { x: i64, y: i64 }  // top-level declarations can come in any order

fn main() {                      // entry point: `main` in the root file
    let p = Point { 1, 2 };
    print("hello ", p);          // hello Point { 1, 2 }
}
```

- Source files are UTF-8 with the `.goose` extension.
- A statement ends with `;`. Constructs that end in a block (`if`, `match`,
  loops, `block`, `guard … else {}`, nested `fn`) need no `;`.
- Trailing commas are allowed in every bracketed list.
- Evaluation is strictly left to right.

---

## 2. Comments, identifiers, keywords

```goose
// line comment
/* block comment /* nested */ still a comment */
```

- **Identifiers**: `[A-Za-z_][A-Za-z0-9_]*`.
- **Keywords**: `import namespace struct enum type fn thread_fn export simd
  recursive let var extern const pad reusable if else while for in loop block
  guard defer match return break continue as true false null self bool varint i8 i16
  i32 i64 u8 u16 u32 u64 f32 f64`
- **Contextual keywords** (keywords only in one position, ordinary names
  elsewhere):
  - `from` after a `return` value
  - `upto` in an index type
  - `inline` and `checkfree` before `fn`
  - `fields`, `variants` and `types` in a `const for` header

---

## 3. Literals

| Kind | Examples | Notes |
|---|---|---|
| Integer | `42`, `0xFF`, `18446744073709551615` | No binary literals and no suffixes. A literal takes its type from context and defaults to `i64`. |
| Float | `1.5`, `2.5e-3`, `1e9`, `0x1.8p3` | `1..2` is a range; `1.` is not a number. Defaults to `f64`. |
| Char | `'a'`, `'\n'`, `'\x41'` | An **integer** (the byte value), not a character type. |
| String | `"hello\n"` | Type `const u8[:]`, read-only static data. |
| Raw string | `"""C:\temp\new"""` | No escapes. |
| Bool | `true`, `false` | |
| Null | `null` | The empty value of an optional `T?`. |
| `self` | `Node { prev: self }` | Only inside a struct literal, for relative-reference fields. |

String and char escapes: `\n \t \r \0 \\ \" \'` and `\xNN` (exactly 2 hex digits).

A multi-line raw string removes the closing `"""`'s indentation from every line:

```goose
let usage = """
    usage: wc [-l] file
      -l   count lines only
    """;
```

---

## 4. Variables: let, var, const

```goose
let answer = 42;            // can't be reassigned (its contents may still be writable)
var count: i32 = 0;         // reassignable; the type annotation is optional
const limits = [10, 20, 30];// no reassignment AND no writes into it

count += 1;
count++;                    // ++ and -- are statements, not expressions

let n: i64;                 // deferred let: assigned exactly once later
if answer > 0 { n = 1; } else { n = 2; }

let xs = [1, 2, 3];
xs[0] = 9;                  // allowed: let only stops reassigning xs itself
```

- Every local must be initialized on every path before it is read.
- Shadowing in an inner scope is allowed.
- `let r .= expr;` binds a **reference** instead of a copy (see §13).
- Type aliases do not create a new type: `type Id = u32;`.

---

## 5. Types at a glance

Types are written **postfix**: `u8[]&` is a reference to an array of bytes.

| Written | Meaning |
|---|---|
| `i8 i16 i32 i64 u8 u16 u32 u64` | integers |
| `f32 f64` | floats |
| `bool` | `true` / `false`, 1 byte |
| `varint` | LEB128 storage type (1–10 bytes); reads as `i64` |
| `T[4]` | fixed array |
| `T[]` / `T[u8]` `T[u16]` `T[u32]` `T[u64]` / `T[varint]` | sized at construction, then frozen (length stored at that width) |
| `T[..8]` | limited: inline capacity 8, grows and shrinks within it |
| `T[..]` | limited: capacity chosen at construction |
| `T[>..]` | **grow-only**, the default growable array |
| `T[>..<]` | **grow-shrink** (stacks, queues, heaps) |
| `T[:]`, `const T[:]` | slice (a view), read-only slice |
| `Point`, `Pair<i64>` | struct, generic struct |
| `Shape`, `Shape..`, `Shape.Circle` | enum in fixed mode, enum in variable mode, one variant as a type |
| `T&`, `T?` | reference, optional (nullable) reference |
| `T&<u32>`, `T&<u32 in pool>`, `T&<u32>?` | relative references |
| `const T`, `const T&`, `const (u8[:])&` | read-only |
| `u32 in a`, `u32 upto a` | index type for global array `a`, bound type |
| `fn(i64) -> bool` | the shape of a function value (used as a bound) |

When a postfix follows an index or relative-reference type, add parentheses:
`(u32 in a)[>..]`, `(Mark..&<u32 in marks>)[>..]`.

---

## 6. Scalars, arithmetic, operators

```goose
let byte: u8 = 255;
let wrapped: u8 = byte + 1;   // 0: arithmetic runs at the operand width, unsigned wraps
let widened = byte + 42;      // the literal adapts to u8 here
let big = byte as i64 + 1000; // a cast is needed to widen explicitly
print(-7 % 3, " ", -7 / 3);   // 2 -2   (% is Euclidean, / truncates toward zero)
```

- **No promotion to `int`**. Mixing widths:
  - A literal adapts to the other operand's type.
  - A narrower type widens implicitly into a wider one (`u8 + i64` gives `i64`).
  - An integer with a float takes the float's type.
  - `u32 + i32` is an error: cast one side.
- **Overflow**:
  - Unsigned arithmetic always wraps.
  - Signed overflow aborts under `--debug` and wraps in release builds.
  - Division by zero always aborts.
- `std` adds `rem(a, b)` (the remainder that goes with `/`) and `div_euclid(a, b)` (the division that goes with `%`).
- **Bool**: there is no int→bool conversion, so write `if n != 0`. `&&` and `||` short-circuit.
- **Floats**: `f32 → f64` and int → float are implicit. A float literal adapts to `f32` when its destination is `f32`.

Operators:

```goose
var flags: u8 = 0;
flags |= 1 << 1;            // bitwise ops: ~ & | ^ << >>
flags &= ~4;
let set = flags & 2 != 0;   // bitwise ops bind tighter than comparisons
let a = [1, 2, 3] + [10, 20, 30];   // memberwise math on fixed arrays and structs
```

- Arithmetic: `+ - * / %`
- Comparison: `< <= > >= == !=`
- Logical: `&& || !`
- Bitwise: `~ & | ^ << >>`
- Reference identity: `.==`, `.!=`
- Assignment: `= .= += -= *= /= %= <<= >>= &= ^= |=`, plus `++` and `--`
- There is **no** ternary `?:`. Use `if` as an expression.

---

## 7. Casts and conversions

```goose
let x = 300;
let a = x as u8;      // range-checked in --debug builds (aborts if the value changes)
let b = x as! u8;     // never checked: deliberate truncation (44)
let c = 2.7 as i64;   // 2: float→int truncates toward zero (NaN gives 0)
let d = 5 as u32;     // fix a literal's type
```

- **Implicit conversions**: same-signedness widening, unsigned→strictly-wider signed, `f32→f64`, any int→float, literals into any type that holds them.
- **Explicit `as` / `as!` needed for**: narrowing, sign changes, `u64`→signed, `f64→f32`, float→int.
- `as` binds tightest: `a as i64 + b` means `(a as i64) + b`.
- A redundant cast is a **warning**.

---

## 8. Arrays

```goose
var fixed: i32[4] = [1, 2, 3, 4];
let zeros: f64[8] = [0.0; 8];        // fill form [value; count]
let frozen: i64[] = [7, 8, 9];       // sized once, never changes
let packed: u8[varint] = "hi";       // 1-byte length + bytes
var small: u8[..8] = [];             // capacity 8, inline
var sized: i64[..] = [..16];         // capacity 16 chosen now, length 0
var grow: i64[>..] = [];             // grow-only: the workhorse
var stack: i64[>..<] = [];           // grow-shrink: the one that pops
var out = [];                        // element type decided by the first push
out.push(2.5);                       // out is now f64[>..]
```

Members (UFCS, so `a.push(v)` is the same as `push(a, v)`):

```goose
var xs: i64[>..<] = [];
xs.push(1);                 // builds in place, returns a reference T&
xs.append([2, 3, 4]);       // append an array, slice or literal
let last .= xs.push(5);     // keep a reference to the new element
print(xs.index_of(last));   // 4
print(xs.len, xs.pop());    // .len is i64; pop returns the last element
xs.resize(6, 0);            // grow with copies of 0 (or shrink)
xs.pop_n(2);
xs.clear();
print(small.cap);           // .cap on limited arrays
```

- References into a `T[>..]` **stay valid forever**, because growth never moves memory.
- `pop`, `clear` and `resize` on a `T[>..]` are allowed only where nothing still points into it (checked by liveness).
- References into a `T[>..<]` may live only in local variables.
- Element rules:
  - Elements of `T[>..<]`, `T[..k]` and `T[..]` must be fixed-size.
  - An array of variable-size elements (e.g. `u8[][>..]`) is **sequential**: you can iterate it but not index it.
- Sizes in `T[k]` and `[v; k]` must be compile-time constants. There are no size generics.
- `==` compares arrays structurally.
- `copy(x)` makes an explicit copy. A non-fixed value is never copied implicitly:

```goose
var b = copy(fixed);   // explicit O(n) copy
let c = grow;          // no copy: c names the same array
```

---

## 9. Strings and printing

There is no string type. A string is a `u8` array:

| Type | Role |
|---|---|
| `u8[>..]` | builder |
| `u8[]`, `u8[varint]` | finished string, stored inline |
| `u8[..16]` | small inline string (in a struct) |
| `u8[:]` / `const u8[:]` | view; a literal is `const u8[:]` |

```goose
var s: u8[>..] = [];
s.append("hello");
s.push(',');                        // push one byte (a char literal)
format(s, " world! ", 6 * 7);       // append the text of any values
let t = str("n=", 42, " pi=", 3.14);// build a fresh u8[>..]
let owned: u8[] = "fixed";          // a writable copy of a literal
print("answer=", 42, " ok=", true); // print takes any values and adds a newline
```

- `print`, `format` and `str` insert **nothing** between their arguments.
- There is **no string interpolation**.
- Text forms:
  - Struct: `Point { 1, 2 }`
  - Array: `[1, 2, 3]`
  - Null optional: `null`
  - Float: the shortest form that reads back the same, e.g. `1.0`
- Gotcha: `'a'` is an integer, so `str('x')` gives `"120"`. Use `.push('x')` to append the byte.

Custom text form, via an overload of the `format` hook:

```goose
struct Person { name: u8[..16], age: i32 }
fn format(out: u8[>..]&, p: Person) { format(out, p.name, " (", p.age, ")"); }
// print(Person { "ann", 30 })  ->  ann (30)
```

String helpers in `std` (they work on `u8[:]`): `find`, `rfind`, `trim`,
`split`, `words`, `join`, `starts_with`, `ends_with`, `parse_int`, `parse_flt`,
`to_lower`, `to_upper`, `each_split`, `each_word`, `each_utf8`, `push_utf8`.

---

## 10. Slices

```goose
let grow: i64[>..] = [10, 20, 30, 40, 50];
let a = grow[1..4];     // [20, 30, 40]: the end is exclusive
let b = grow[..2];      // first two
let c = grow[2..];      // from index 2
let d = grow[^2..];     // last two (^k means len - k)
let e = grow[..];       // whole array

fn total(xs: i64[:]) -> i64 { var t = 0; for x in xs { t += x; } return t; }
// total(grow), total(fixed), total(grow[1..3]): every array kind coerces to a slice
```

- A slice is a reference plus a length. It never copies elements.
- A slice of a `var` array is writable; a literal or a slice of a `const` value is not.
- Declare a parameter `const T[:]` to document that the function only reads it.
- A slice cannot outlive its root, and the array cannot shrink while the slice is still used.

---

## 11. Structs

```goose
struct Unit { kind: i32, hp: i32 = 100, x: f32 = 0.0, name: u8[..16] }

let a = Unit { kind: 1, x: 1.5, name: "scout" };   // named fields (any order)
let b = Unit { 2, 50, 0.0, "tank" };               // positional
let c = Unit { kind: 3, .. };                      // `..` fills the rest with defaults
let d = default<Unit>();                           // every field at its default
var e = Unit { .. };
e.hp -= 10;                                        // field access with .
```

Field kinds:

```goose
struct Hdr {
    magic: u8[4],
    pad,                 // align the next field (or `pad 3` for 3 unused bytes)
    size: u32,
    let kind: u8,        // can't be assigned after construction
    const name: u8[..8], // contents are read-only too
}

struct Item  { sku: u8[varint], qty: varint, cents: varint }       // variable-size fields, inline
struct Order { id: varint, customer: u8[varint], items: Item[varint] }

struct Stack { name: u8[..8], items: i64[>..<] }   // only the LAST field may be resizable

struct Pair<T> { a: T, b: T }                      // generic struct
let p = Pair<i64> { 1, 2 };
let q = Pair { a: 0.5, b: 1.5 };                   // T inferred
```

- Structs are **packed** (no padding) and **nominal**.
- `==` compares memberwise. A reference field compares by identity.
- An optional field with no default is `null` when left out.
- A `varint` field is written only at construction.

---

## 12. Enums and match

```goose
enum Shape { Circle { r: f64 }, Rect { w: f64, h: f64 }, Dot }

let s = Shape.Circle { r: 1.0 };   // variant literal
let t = Shape.Dot;                 // a variant with no payload
```

Two storage modes, chosen where the type is used:

```goose
var fixedm: Shape[>..] = [];       // fixed mode: tag + largest payload; indexable, overwritable
var packed: Shape..[>..] = [];     // variable mode: each value only as big as its variant
packed.push(Shape.Rect { w: 2.0, h: 3.0 });
```

`match` is an expression:

```goose
for s in packed {
    match s {
        Circle c => print("circle ", c.r),   // bind a copy of the payload
        Rect &r => { r.w += 1.0; },          // bind by reference (variable mode only)
        Dot => print("dot"),                 // no binding
    }
}
let round = match s { Circle, Dot => true, Rect => false };   // several variants per arm
let msg = match s { Circle c => "c", _ => "other" };          // `_` covers the rest
```

Matching integers, with literals, named constants, half-open ranges and comma lists:

```goose
let LAVA = 7;    // (a global named constant)
let level = match hp { 0 => "dead", 1..LAVA => "low", LAVA, 90..95, -3 => "odd", _ => "fine" };
```

- Arms are separated by commas. A multi-statement arm uses `{ … }`.
- The first matching arm wins. An arm that earlier arms fully cover is a compile error.
- A match must be exhaustive. An integer match needs `_`.
- There are no match guards (`if`), no `|` alternatives (use `,`), no `..=`, and no destructuring of struct fields in patterns.

**Case functions**: one overload per variant, dispatched on the tag:

```goose
fn area(s: Shape.Circle) -> f64 { 3.14159 * s.r * s.r }
fn area(s: Shape.Rect) -> f64   { s.w * s.h }
fn area(s: Shape.Dot) -> f64    { 0.0 }
// for s in packed { print(area(s)); }     // the compiler checks every variant is covered
```

Recursive enums go through relative references (§14):

```goose
enum Expr { Num { v: f64 }, Add { l: Expr..&<u16>, r: Expr..&<u16> } }
```

---

## 13. References and optionals

```goose
var xs: i64[>..] = [10, 20, 30];
var r .= xs[0];        // .= binds a reference (= would copy)
r = 11;                // writes xs[0]: references are transparent, with no * or ->
r .= xs[2];            // rebind to another element
r += 1;
print(r .== xs[2]);    // .== / .!= compare addresses; == compares values
let p = &xs[1];        // & makes a reference explicitly
```

Reference parameters and fields bind an lvalue **without** `&`:

```goose
fn inc(n: i64&) { n += 1; }
var count = 0;
inc(count);                         // count is now 1
let rr: i64& = count;               // an annotated reference variable
```

Optionals `T?`: a nullable reference that must be **narrowed** before use:

```goose
fn first_at_least(xs: i64[:], min: i64) -> i64? {
    for &x in xs { if x >= min { return x; } }
    return null;
}

let data = [1, 7, 3];
let o = first_at_least(data, 5);
if o { print("got ", o); } else { print("none"); }     // narrowed by if
// while cur { sum += cur.v; cur .= cur.next; }        // narrowed by while
// guard o else { return 0; }                          // narrowed by guard
// assert(o);                                          // narrowed by assert
print(o == null);
```

- References are never null, never dangle, and allow no pointer arithmetic.
- A `let` reference cannot be rebound, but you can still write through it.
- A fixed-size value **decays to a copy** with `let x = r;`. Use `let x .= r;` to keep the reference.
- A non-fixed value always binds by reference.
- You cannot take a reference into a temporary: bind the temporary to a variable first.

---

## 14. Relative references

Links stored as narrow offsets. They are position-independent and serializable.

```goose
struct Node { key: i32, left: Node&<u32>?, right: Node&<u32>? }   // 12 bytes, links included

fn insert(pool: Node[>..]&, key: i32) {
    if pool.len == 0 { pool.push(Node { key: key }); return; }
    var cur .= pool[0];
    loop {
        if key == cur.key { return; }
        let next = if key < cur.key { cur.left } else { cur.right };
        if next { cur .= next; continue; }              // narrowed to Node&
        if key < cur.key { cur.left .= pool.push(Node { key: key }); }
        else             { cur.right .= pool.push(Node { key: key }); }
        return;
    }
}
```

| Form | Meaning |
|---|---|
| `T&<u8 \| u16 \| u32 \| u64 \| varint>` | self-relative: the offset from the field to a target in the same array |
| `T&<u32 in pool>` | pool-relative: the offset from the base of the global array `pool` |
| `T&<u32>?` | optional; offset 0 means null |
| `self` | in a literal: a link to the value being built |

```goose
struct Ring { val: i64, prev: Ring&<u32 in ring>, next: Ring&<u32 in ring> }
reusable var ring: Ring[>..] = [];
// let head = ring.alloc_index(Ring { val: 0, prev: self, next: self });
```

- A value holding self-relative links cannot be copied. Build it in place, bind it with `.=`, and use `&` binders in `match`.

---

## 15. Control flow

`if`, `match`, `block` and `{ }` are **expressions**. A block's value is its
last expression (no `;` after it).

```goose
// if / else if / else
let kind = if hp > 50 { "healthy" } else if hp > 0 { "hurt" } else { "down" };
if hp > 0 { print(kind); }                       // statement form; no else needed
let v = (if hp > 2 { 1 } else { 2 }) + 3;        // parenthesize to use it as an operand

// block: gives `break` a target, with a value
let verdict = block {
    guard alive else { break "gone"; }
    guard hp > 0 else { break "dead"; }
    "standing"
};

// bare block: a scope with a value
let doubled = { let tmp = hp + 1; tmp * 2 };

// guard: continue only if the condition holds
fn half(n: i64) -> i64 { guard n % 2 == 0 else { return -1; } n / 2 }
for i in 5 { guard i % 2 == 0; print("even ", i); }   // no else: skips the rest of the body
```

`guard c;` without `else` skips the rest of the enclosing body:

- in a function, it returns;
- in a loop, it continues with the next iteration;
- in a block, it ends that call.

`defer` runs a statement or block when the enclosing block ends, however it
ends (end of block, `break`, `continue`, `return`, or a `return … from`
passing through):

```goose
fn describe(items: i64[:]) -> i64 {
    depth++;
    defer depth--;                     // every way out restores it
    var count = 0;
    for x in items {
        defer count++;                 // runs at the end of every iteration
        if x < 0 { continue; }
        if x > 100 { return -1; }
    }
    return count;
}
{ defer print("block done"); print("in the block"); }   // in the block, block done
```

- Several defers run latest first, and only the ones the exit has passed.
- The body sees variables as they are at the exit.
- A defer body cannot `return`, `break` or `continue` out of itself, cannot use
  long-distance returns, and cannot name the function's named result.
- `abort`, a failed `assert` and `exit` run no defers.

---

## 16. Loops

```goose
for i in 3 { }                  // 0, 1, 2
for i in 10..13 { }             // 10, 11, 12 (half-open)
for i: i32 in 0..10 { }         // typed loop variable
for i: u8 in 0..256 { }         // every u8
for x in xs { }                 // by value (fixed-size elements)
for &x in xs { x *= 2; }        // by reference: mutate in place
for x, i in xs { }              // element plus index (i64)
for x, i: u8 in grid { }        // narrower index type (grid: u8[16]; the length must fit u8)
for v in [3, 0, 4] { }          // over a literal
while cond { }
loop { if done { break; } }     // infinite loop
let found = loop { n += 7; if n % 5 == 0 { break n; } };   // a loop with a value
```

- `break`, `break value;` and `continue`. There are **no labels**.
- There is no `step` and no reverse range. Use `while`, a helper function, or
  `each_rev(xs) { … }` / `reverse(xs)` from `std`.
- Pushing to a growable array during a by-value `for` over it extends the walk.

---

## 17. Functions

```goose
fn add(a: i64, b: i64) -> i64 { a + b }          // the last expression is the result
fn add2(a: i64, b: i64) -> i64 { return a + b; }
fn greet() { print("hi"); }                      // no result
fn twice(x) { x + x }                            // untyped parameter = generic
fn scaled(a: i32, b: i32 = 0, c: f32 = 1.0) -> f32 { (a + b) * c }   // trailing defaults
fn bump(var n: i64) -> i64 { n += 1; n }         // `var` parameter: reassignable local copy
fn inc(n: i64&) { n += 1; }                      // reference parameter
fn sum(xs: i64[:]) -> i64 { var t = 0; for x in xs { t += x; } t }   // slice parameter
```

**Multiple results** (a calling convention, not a tuple):

```goose
fn divide(a: i64, b: i64) -> i64, bool {
    if b == 0 { return 0, false; }
    return a / b, true;
}
let q, ok = divide(7, 2);     // bind both
var r = 0; var f = false;
r, f = divide(1, 0);          // assign to existing places
let only_q = divide(9, 3);    // a value context takes the first result
```

**UFCS**: `x.f(a)` is the same as `f(x, a)`. It works on literals too: `7.limit(0, 5)`.

**Overloading** is resolved statically, by parameter types. The expected
result type never selects an overload.

```goose
fn describe(x: i64) -> u8[>..] { str("int ", x) }
fn describe(x: f64) -> u8[>..] { str("float ", x) }
```

**Nested functions** can read and write the enclosing function's locals:

```goose
fn main() {
    var total = 0;
    fn add(v: i64) { total += v; }
    add(3); add(4);
    print(total);   // 7
}
```

- Free functions only: no methods, no `impl`, no classes.
- There are no named arguments. Only trailing parameters with defaults can be omitted.
- The result type may be omitted and is then inferred. It must be written for recursive functions.

---

## 18. Generics, function values, blocks

```goose
fn span<T>(a: T, b: T) -> T { if a > b { a - b } else { b - a } }
fn zero<T>() -> T { default<T>() }
let z = zero<f64>();                     // explicit type argument when it can't be inferred
```

- Everything is monomorphized. There are no trait bounds; each instantiation is checked separately.

**Function values** are compile-time type parameters. A call through one is
direct and can be inlined.

```goose
fn each_step<F>(lo: i64, hi: i64, step: i64 = 1) {
    var i = lo;
    while i < hi { F(i); i += step; }
}
fn apply<F: fn(i64)>(a: i64) { F(a); }   // optional bound (documentation only)
fn show(v: i64) { print(v); }

each_step(0, 10, 3) { print(it); };      // trailing block with the implicit parameter `it`
each_step(0, 10) { i => print(i); };     // named block parameter
apply(5, show);                          // pass a named function
```

Common patterns with `std`:

```goose
let evens = xs.filter() { it % 2 == 0 };
let total = fold(xs, 0) { acc, x => acc + x };
let doubled = xs.map() { it * 2 };
let big = xs.find() { it > 10 };
sort(xs) { a, b => a > b };
```

- `return` inside a block returns from the **enclosing named function**:

```goose
fn first_multiple_of_7(lo: i64, hi: i64) -> i64 {
    each_step(lo, hi, 3) { if it % 7 == 0 { return it; } };
    return -1;
}
```

- A call takes one trailing block; pass any others by name.
- A function value cannot be stored, returned or put in data. There are no closures and no function pointers.
- A trailing-block call used as a statement is followed by `;`.

---

## 19. Recursion

Recursion is opt-in. Mark the entry of each recursive cycle with `recursive`:

```goose
struct Tree { key: i32, left: Tree&<u32>?, right: Tree&<u32>? }

recursive fn count(n: Tree?) -> i64 {
    guard n else { return 0; }
    return 1 + count(n.left) + count(n.right);
}
```

- Every function in the cycle needs a fully written signature.
- No non-fixed local (such as a growable array or a `str(...)` temporary) may be live across the recursive call. Put scratch data in a `{ }` block that ends before the call, or pass in a `T[>..<]&` and restore its length with `resize(mark)`.

---

## 20. Errors: return … from, assert, abort

**`return E from f`** returns `E` as the result of the innermost active call
of `f`, however many frames up that call is. It is checked statically.

```goose
struct User { name: u8[..16], age: i32 }

fn load(text: u8[:]) -> User[>..], u8[] {
    var users: User[>..] = [];
    each_split(text, '\n') { users.push(parse_user(it)); };
    return users, "";
}

fn parse_user(line: u8[:]) -> User {                 // a plain signature: no Result type
    let comma = find(line, ",");
    guard comma >= 0 else { return [], str("expected name,age: ", line) from load; }
    let age, ok = parse_int(line[comma + 1..]);
    guard ok else { return [], str("bad age: ", line) from load; }
    return User { name: trim(line[..comma]), age: age as i32 };
}
```

Exceptions, from the `exception` library module:

```goose
import exception;
fn risky() { exception::throw(str("bad item ", 42)); }
// exception::try<u8[]>(risky) { e => print("caught ", e); };
// exception::try<u8[]>(risky, catch_fn, finally_fn);   // finally_fn runs on every way out
```

Stopping the program (none of these can be caught):

```goose
assert(x > 0);        // abort unless true (also narrows an optional)
abort("message");     // abort with a message; never returns
exit(1);              // end the program with an exit code
```

---

## 21. Pools: reusable and reusable[]

A pool is a grow-only array with a hidden freelist, for data whose lifetimes don't nest.

```goose
struct Job { n: i32 }

reusable var pool: Job[>..] = [];
let i0 = pool.alloc_index(Job { 1 });      // the index of a slot (reuses a freed one)
pool.free(i0);                             // put the slot back
let jr .= pool.alloc_ref(Job { 2 });       // a reference to a slot
pool.free(pool.index_of(jr));              // reference → index → free

reusable[] var spans: i64[>..] = [];       // slice pool
let s1 = spans.alloc_slice(3);             // 3 default-valued elements
let s2 = spans.realloc_slice(s1, 5);       // resize, in place if possible
spans.free_slice(s2);
```

- `free` never releases memory. A stale reference reads a valid value of the right type (a logic bug, but never memory corruption).

---

## 22. Index types and checkfree

An index type is an integer proven to be in range for one specific global
array. Indexing with it needs no bounds check.

```goose
var weights: i32[>..];
type WId = u32 in weights;          // always < weights.len
var edges: WId[>..];
struct Span { lo: u32 upto edges, hi: u32 upto edges }   // upto: <= edges.len

checkfree fn total(ids: WId[:]) -> i64 {    // compile error if any bounds check remains
    var t = 0;
    for id in ids { t += weights[id]; }
    return t;
}

// weights.push(5);
// edges.push(0 as WId);             // `as` is checked at runtime in every build; `as!` is not allowed
```

- The array must be a global `var` grow-only array of fixed-size elements, and it can never shrink.
- An index converts implicitly to a plain integer.
- `assert(b.len >= a.len)` lets the compiler remove checks on `b[i]`, for an `i` that is an index into `a`.
- `goose --bce-lines` reports which bounds checks remain on each line.

---

## 23. const for (compile-time expansion)

The body is copied once per entry at compile time. There is no runtime reflection.

```goose
fn show_fields<T>(v: T&) {
    const for <N, A> in fields<T> { print(N, " = ", v.A); }    // N: name, A: accessor
}

fn describe<T>(value: T) {
    match value {
        const for <N, V> in variants<T> { V v => { print(N); }, }
    }
}

// const for <U> in types<i8, u16, f32> { print(default<U>()); }
// const for <C> in [1, 2, 4] { let a: u8[C] = [0; C]; print(a.len); }
```

Fields can also be generated in a constructor:
`T { const for <N, A> in fields<T> { A: F(N, v.A), } }`.

---

## 24. Modules, packages, namespaces, globals

```goose
import std;                         // stdlib module
import dictionary;
import util.strings;                // util/strings.goose, relative to the package root
import .helpers;                    // relative to this file
import mylib from "./lib";          // package from a directory (root file only)
import other from "owner/repo@v1";  // package from GitHub at a tag or commit
```

- An import includes a file once and creates no namespace by itself.

```goose
namespace geo;                      // at the top of a file
struct Pt { x: i64, y: i64 }
fn norm1(p: Pt) -> i64 { (if p.x < 0 { -p.x } else { p.x }) + p.y }
fn ::main() {                       // declared in the global namespace
    let p = geo::Pt { -3, 4 };
    print(geo::norm1(p), " ", p.norm1());   // UFCS searches the receiver type's namespace first
}
```

- `::name` names the global declaration that a namespaced one shadows.
- There is no privacy, no re-export and no nesting of namespaces.

Globals:

```goose
var log: u8[>..];                    // a var with only a type starts empty or default
let NAMES = ["ada", "grace"];        // an untyped const global = named constant / static data
let SIZE = 16;
var grid: u8[SIZE] = [0; SIZE];      // named constants work as sizes
let data = embed_file("table.bin");  // file bytes read at compile time (const u8[:])
```

- Globals are initialized before `main`: imported files first, then in declaration order.
- Program arguments: `args()`, `arg(i)` and `arg_count()` from `os` (global namespace).

---

## 25. Threads

There is no shared memory. Every `thread_fn` is compiled as a separate program
with its own memory. Values pass through typed queues and must be **flat** (no
references or slices).

```goose
struct Job { n: i32 }
struct Res { n: i32, sq: i64 }

thread_fn worker() {
    loop {
        let job = qget<Job>();                 // blocks on the queue for Job
        guard job.n >= 0 else { break; }
        qput(Res { n: job.n, sq: job.n as i64 * job.n });
    }
}

fn main() {
    for i in 4 { qput(Job { n: i as i32 }); }
    for i in 2 { qput(Job { n: -1 }); }        // stop signals
    var ids: i64[>..] = [];
    for i in 2 { ids.push(thread_spawn(worker)); }
    var sum = 0;
    for i in 4 { sum += qget<Res>().sq; }
    for id in ids { thread_wait(id); }
    print(sum);
}
```

| Builtin | Meaning |
|---|---|
| `thread_spawn(f, args…)` | start a worker; returns an id |
| `thread_spawn_contained(f, args…)` | a worker whose abort ends only that worker |
| `thread_wait(id)` / `thread_wait(id, msg)` | wait for a worker; `false` if a contained worker aborted (its message goes into `msg`) |
| `qput(v)` | send to the queue for `v`'s type |
| `qget<T>()` / `qget<T>(ms)` | receive (blocking / with a timeout → `T, bool`) |
| `qpoll<T>()` | receive without blocking → `T, bool` |
| `qlimit<T>(n)` | cap the queue's size |
| `hardware_threads()` | a sensible worker count |

Build threaded programs with `goose build`; the JIT cannot run them.

---

## 26. Serialization

```goose
var image: u8[>..] = tree.to_bytes();            // a framed byte image of an array
to_bytes(tree, image);                           // or append to an existing buffer
let view = bytes_of(tree);                       // the raw element bytes, no copy
var loaded, ok = from_bytes<Node[>..]>(image);   // verified: a bad image gives false and an empty array
```

---

## 27. Calling C / being called from C

```goose
extern fn hypot(x: f64, y: f64) -> f64;           // a C symbol with the same name
extern fn cube_root(x: f64) -> f64 = "cbrt";      // a different C name
extern fn crc32_bytes(s: const u8[:]) -> u32;     // a slice crosses as { data, len }
extern fn fill(out: Stats&);                      // a struct filled through a pointer
extern fn c_version(out: u8[>..]&);               // a builder that C appends to

extern "SDL2" {                                   // a shared library, loaded with dlopen at startup
    fn SDL_Init(flags: u32) -> i32;
    fn SDL_Quit();
    fn delay(ms: u32) = "SDL_Delay";
}

export fn hello() -> const u8[:] { return "Hello!" }      // callable from C
export "c_add" fn add(a: i32, b: i32) -> i32 { a + b }    // with a chosen C name
```

- Types that can cross: scalars, `bool`, flat fixed-size structs, `T&` (as a pointer), `T[:]` (as data + length), `u8[>..]&` (as a builder).
- Opaque handles are `u64`.
- Your own C goes in a `foo.build` sidecar beside `foo.goose`: `c_sources = ["impl.c"];`.
- To use Goose from a C host: `goose --standalone --header hello.h -o hello.c hello.goose`, and call `goose_init(argc, argv)` once.

---

## 28. Function qualifiers

The order is fixed: `export`/`extern` → `checkfree` → `simd` → `inline` →
`recursive` → `fn`/`thread_fn`.

| Qualifier | Meaning |
|---|---|
| `recursive fn` | the entry of a recursive cycle |
| `inline fn` | always inlined |
| `simd fn` | built in baseline, AVX2 and AVX-512 versions, picked at runtime |
| `checkfree fn` | no bounds check may remain |
| `thread_fn` | a worker entry point |
| `extern fn` | a C function |
| `export fn` | a Goose function callable from C |

```goose
inline fn clamp01(x: f32) -> f32 { if x < 0 { 0 } else if x > 1 { 1 } else { x } }
simd fn checksum(xs: u8[:]) -> u32 { var h: u32 = 0; for x in xs { h += x as u32 * 31 + 7; } h }
```

---

## 29. Builtins and array members

| Builtin | Meaning |
|---|---|
| `print(a, b, …)` | print the values and a newline |
| `str(a, b, …)` | a fresh `u8[>..]` holding their text |
| `format(out, a, b, …)` | append their text to `out` |
| `assert(c)`, `abort(msg)`, `exit(code)` | checks and stopping |
| `copy(x)` | an explicit copy |
| `default<T>()` | the default value of `T` |
| `to_bytes`, `bytes_of`, `from_bytes<T>` | serialization |
| `embed_file(path)`, `embed_shader(…)` | compile-time file or shader embedding |
| `thread_spawn`, `thread_spawn_contained`, `thread_wait`, `hardware_threads` | threads |
| `qput`, `qget<T>`, `qpoll<T>`, `qlimit<T>` | queues |

- **Array members**: `.len .cap .push .append .pop .pop_n .resize .clear .index_of`
- **Pool members**: `.alloc_index .alloc_ref .free .alloc_slice .realloc_slice .free_slice`

---

## 30. Operator precedence

From tightest to loosest (the same as Rust):

| Level | Operators |
|---|---|
| postfix | `f(…)` `a[i]` `a[x..y]` `.field` `x as T` `x as! T` |
| unary | `-` `!` `~` `&` |
| multiplicative | `*` `/` `%` |
| additive | `+` `-` |
| shift | `<<` `>>` |
| bitwise and | `&` |
| bitwise xor | `^` |
| bitwise or | `\|` |
| comparison | `<` `<=` `>` `>=` |
| equality | `==` `!=` `.==` `.!=` |
| logical and | `&&` |
| logical or | `\|\|` |

- Assignments (`=`, `.=`, `op=`, `++`, `--`) are statements, not expressions.
- A range `a..b` appears only in slicing brackets, `for` headers and `match` arms.

---

## 31. Standard library quick list

| Module | Import | Highlights |
|---|---|---|
| `std` | `import std;` | `min max clamp abs sign swap sort stable_sort filter map fold find find_index any all sum reverse each_rev dedup retain heap_push heap_pop binary_search lower_bound find split trim words join parse_int parse_flt to_lower to_upper rand_int rand_flt hash` |
| `dictionary` | `import dictionary;` | `var d = dictionary<const u8[:], i64> {}`, then `d.insert(k, v)`, `d.get(k)` (gives `V?`), `d.contains(k)`, `d.update(k, 0) { it += 1; };`, `d.remove(k)`, `d.each() { … }` |
| `vec` | `import vec;` | `vec2/3/4<T>`, `float3`, `int2`, … |
| `math` | `import math;` | `sin cos tan asin acos atan sqrt pow exp log floor ceil round trunc mul_add radians degrees is_nan is_inf is_finite` (the last four also take `f32`) |
| `os` | `import os;` | `read_file write_file write_file_atomic append_file delete_file rename_file file_exists is_dir make_dir delete_dir list_dir read_line read_stdin write_stdout write_stderr args arg arg_count env time time_ns clock clock_ns sleep sleep_ms resource_dir` |
| `exception` | `import exception;` | `exception::try<E>(body) { e => … }`, `exception::try<E>(body, catch, finally)`, `exception::throw(v)` |
| `json`, `csv`, `regex`, `base64`, `binary`, `ffi` | `import json;` … | namespaced: `json::…`, `csv::…`, `regex::…` |
| `gfx`, `audio`, `ui`, `physics` | external packages | graphics (SDL3 GPU), audio, Nuklear UI, Box3D physics |

`docs/stdlib.md` lists every function's signature.

---

## 32. What Goose does NOT have

Goose deliberately does not have:

- Heap allocation, GC, refcounting or destructors.
- Lifetime annotations or `unsafe`.
- Classes, methods, `impl`, inheritance, traits or vtables. Use free functions + UFCS + enums.
- Closures that escape, or function pointers.
- A tuple type. Use multiple results instead.
- A ternary `?:`. Use `if` as an expression.
- String interpolation. Use `print(a, b, c)` / `str(...)`.
- Named or keyword arguments. Only trailing defaults.
- Binary literals or numeric suffixes.
- Labeled `break`, `step` ranges or reverse ranges.
- Exceptions as a language feature (the `exception` module is a library; its `finally` is a `defer`).
- Implicit int↔bool conversion, or implicit narrowing.
- Operator overloading. Only the `format` hook for printing.
- Shared memory between threads, locks or atomics.
- Size generics (`fn f<N>(a: T[N])`).
