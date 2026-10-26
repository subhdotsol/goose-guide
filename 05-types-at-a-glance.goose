// ===================================================================
// 05 - Types at a glance (syntax.md section 5)
// ===================================================================
// Types are written POSTFIX: you read them left to right, each suffix
// wrapping what came before.  `u8[]&` = "u8, array of it, reference to that"
// = a reference to an array of bytes.
// This file shows one small example of EVERY row of the cheat-sheet table.
// Later sections (8, 10-14, 18, 22) cover each in depth.
// ===================================================================
import std;

// ---- declarations used by main (top-level order doesn't matter) ----

struct Point { x: i64, y: i64 }                 // a plain struct type: `Point`
struct Pair<T> { a: T, b: T }                   // a generic struct: `Pair<i64>`, `Pair<f64>`...

// an enum (algebraic data type) with three variants
enum Shape { Circle { r: f64 }, Rect { w: f64, h: f64 }, Dot }

// `varint` is a STORAGE type for fields/elements: 1-10 bytes (LEB128).
// Reading it gives an i64; it can only be written when the struct is built.
struct Rec { id: varint, name: u8[] }

// Self-relative reference: `Node&<u32>?` is an OPTIONAL link stored as a
// u32 offset from the field to the target node in the same array.
struct Node { key: i32, next: Node&<u32>? }

// Pool-relative reference: `Ring&<u32 in ring>` is a u32 offset from the
// start of the global array `ring`.  `self` in a literal = "link to me".
struct Ring { val: i64, next: Ring&<u32 in ring> }
reusable var ring: Ring[>..] = [];

// Index types: `u32 in weights` is an integer PROVEN < weights.len, so
// indexing `weights` with it needs no bounds check. `u32 upto weights`
// is a bound: <= weights.len. The array must be a global grow-only var.
var weights: i32[>..];
type WId = u32 in weights;
struct Span { lo: u32 upto weights, hi: u32 upto weights }
// When a postfix follows an index type, parenthesize it:
var picked: (u32 in weights)[>..];              // a grow-only array OF index values

// `fn(i64) -> bool` is the SHAPE of a function value, used as a bound
// on a function-value type parameter (documentation only). The function
// itself is passed as an extra trailing argument: count_if(xs, is_even).
fn count_if<F: fn(i64) -> bool>(xs: i64[:]) -> i64 {
    var n = 0;
    for x in xs { if F(x) { n += 1; } }
    return n;
}
fn is_even(v: i64) -> bool { v % 2 == 0 }

// A function taking a reference `T&` and a read-only reference `const T&`.
fn bump(n: i64&) { n += 1; }                    // writes through the reference
fn peek(p: const Point&) -> i64 { p.x }         // may read, cannot write
// `const (u8[:])&` = read-only reference to a SLICE VARIABLE (parens move
// the const outward; plain `const u8[:]` would mean "read-only bytes").
fn slice_len(s: const (u8[:])&) -> i64 { s.len }

fn main() {
    // ---------------------------------------------------------------
    // Integers: i8 i16 i32 i64 (signed), u8 u16 u32 u64 (unsigned)
    // ---------------------------------------------------------------
    let a: i8 = -128;  let b: i16 = 32767;  let c: i32 = -5;  let d: i64 = 9;
    let e: u8 = 255;   let f: u16 = 65535;  let g: u32 = 7;   let h: u64 = 18446744073709551615;
    print("ints: ", a, " ", b, " ", c, " ", d, " ", e, " ", f, " ", g, " ", h);

    // ---------------------------------------------------------------
    // Floats: f32 f64
    // ---------------------------------------------------------------
    let f1: f32 = 1.5;
    let f2: f64 = 2.25;
    print("floats: ", f1, " ", f2);

    // ---------------------------------------------------------------
    // bool: true / false, stored in 1 byte
    // ---------------------------------------------------------------
    let ok: bool = true;
    print("bool: ", ok, " ", !ok);

    // ---------------------------------------------------------------
    // varint: LEB128 storage, reads back as i64
    // ---------------------------------------------------------------
    let rec = Rec { id: 300, name: "goose" };   // 300 is stored in 2 bytes
    let as_i64: i64 = rec.id;                   // reading a varint gives an i64
    print("varint field: ", as_i64, " name: ", rec.name);

    // ---------------------------------------------------------------
    // The array family
    // ---------------------------------------------------------------
    let fixed: i64[4] = [1, 2, 3, 4];           // T[4]: fixed array, size known at compile time
    let frozen: i64[] = [7, 8, 9];              // T[]: sized at construction, then frozen (u32 length)
    let short_len: u8[u8] = "hi";               // T[u8]: same, but the length is stored as a u8
    let wide_len: i64[u64] = [1, 2];            // T[u16] / T[u32] / T[u64] likewise
    let packed: u8[varint] = "bye";             // T[varint]: the length is a varint (1 byte here)
    var small: u8[..8] = [];                    // T[..8]: inline capacity 8, grows/shrinks within it
    small.push('o'); small.push('k');
    var sized: i64[..] = [..16];                // T[..]: capacity (16) chosen at construction
    sized.push(42);
    var grow: i64[>..] = [];                    // T[>..]: GROW-ONLY, the default growable array
    grow.push(1); grow.push(2);
    var stack: i64[>..<] = [];                  // T[>..<]: GROW-SHRINK (stacks, queues, heaps)
    stack.push(10); stack.push(20);
    let top = stack.pop();                      // only shrinkable arrays can pop freely
    print("T[4]=", fixed, " T[]=", frozen, " T[u8]=", short_len, " T[u64]=", wide_len,
          " T[varint]=", packed);
    print("T[..8]=", small, " ", small.len, "/", small.cap, "  T[..]=", sized, " cap ", sized.cap,
          "  T[>..]=", grow, "  T[>..<]=", stack, " popped ", top);

    // ---------------------------------------------------------------
    // Slices: T[:] is a view into elements; const T[:] is a read-only view
    // ---------------------------------------------------------------
    var nums = [1, 2, 3, 4, 5];
    let view: i64[:] = nums[1..4];              // a writable view of 2, 3, 4
    view[0] = 20;                               // writes nums[1]
    let ro: const i64[:] = nums[..2];           // a read-only view
    print("slice: ", view, " const slice: ", ro, " nums: ", nums);
    // ro[0] = 1;                               // ERROR: cannot assign through a const view

    // ---------------------------------------------------------------
    // Structs and generic structs
    // ---------------------------------------------------------------
    let p: Point = Point { 1, 2 };
    let pi: Pair<i64> = Pair { 3, 4 };          // Pair instantiated at i64
    let pf: Pair<f64> = Pair { 0.5, 1.5 };      // ...and at f64: a different type
    print("struct: ", p, " generic: ", pi, " ", pf);

    // ---------------------------------------------------------------
    // Enums: Shape (fixed mode), Shape.. (variable mode), Shape.Circle (one variant)
    // ---------------------------------------------------------------
    var shapes_fixed: Shape[>..] = [];          // fixed mode: tag + largest payload per element
    shapes_fixed.push(Shape.Dot);
    var shapes_var: Shape..[>..] = [];          // variable mode: each value only as big as its variant
    shapes_var.push(Shape.Rect { w: 2.0, h: 3.0 });
    let circ: Shape.Circle = Shape.Circle { r: 1.0 };   // a single variant used as a type
    print("enum: ", shapes_fixed.len, " fixed, ", shapes_var.len, " variable, circle r = ", circ.r);

    // ---------------------------------------------------------------
    // References T& and optionals T?
    // ---------------------------------------------------------------
    var count = 0;
    let r: i64& = count;                        // an annotated reference variable
    r += 5;                                     // writes count (references are transparent)
    bump(count);                                // a T& parameter binds the lvalue, no `&` needed
    let maybe: i64? = null;                     // an optional reference, currently null
    let some: i64? = count;                     // an optional pointing at count
    print("ref: count = ", count, " maybe null? ", maybe == null, " some = ", some);

    // ---------------------------------------------------------------
    // Relative references: T&<u32>, T&<u32 in pool>, T&<u32>?
    // ---------------------------------------------------------------
    var list: Node[>..] = [];
    let first .= list.push(Node { key: 1 });    // `next` defaults to null
    first.next .= list.push(Node { key: 2 });   // link stored as a u32 offset
    let nx = first.next;                        // copy the optional link into a local...
    if nx { print("self-relative: ", first.key, " -> ", nx.key); }   // ...so `if` can narrow it
    let head .= ring.push(Ring { val: 7, next: self });   // links to itself
    print("pool-relative: ", head.val, " -> ", head.next.val);

    // ---------------------------------------------------------------
    // const T, const T&, const (u8[:])&
    // ---------------------------------------------------------------
    const frozen_pt: Point = Point { 9, 9 };    // const T: contents read-only
    let msg: const u8[:] = "hello";             // const u8[:]: a view of READ-ONLY bytes
    var bytes: u8[>..] = [];
    bytes.append(msg);                          // a writable copy of the bytes
    var sl: u8[:] = bytes[..];                  // a slice variable of WRITABLE bytes
    // slice_len(msg) would be an error: a `const u8[:]` is not a `u8[:]`
    // (const (u8[:])& makes the REFERENCE read-only, not the bytes).
    print("const: ", peek(frozen_pt), " ", msg, " ", slice_len(sl));

    // ---------------------------------------------------------------
    // Index types: u32 in weights / u32 upto weights
    // ---------------------------------------------------------------
    weights.push(5); weights.push(6);
    let w: WId = 1 as WId;                      // `as` into an index type is range-checked at runtime
    picked.push(w);
    let sp = Span { lo: 0 as u32 upto weights, hi: 2 as u32 upto weights };
    let plain: i64 = w;                         // an index converts implicitly to a plain integer
    print("index type: weights[w] = ", weights[w], " picked ", picked.len,
          " span ", sp.lo, "..", sp.hi, " plain ", plain);

    // ---------------------------------------------------------------
    // fn(i64) -> bool as a bound on a function value
    // ---------------------------------------------------------------
    let data = [1, 2, 3, 4, 6];
    print("fn bound: evens = ", count_if(data, is_even));
}
