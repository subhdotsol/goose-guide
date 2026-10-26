import std;

// =====================================================================
// 11 - Structs (syntax.md section 11, docs/reference.md section 8)
//
// A struct is its fields in declaration order, PACKED (no padding is ever
// inserted). Struct types are NOMINAL: two structs with identical fields
// are still different types.
// =====================================================================

// ---------------------------------------------------------------------
// Declaration with field defaults: `name: Type = default`.
// A default is an expression evaluated at EACH construction that leaves
// the field out (it may call functions / read globals, but never the
// constructor's locals or sibling fields).
// ---------------------------------------------------------------------
struct Unit { kind: i32, hp: i32 = 100, x: f32 = 0.0, name: u8[..16] }

// A global `var` given only a type starts at its type's default value.
var selected: Unit;

// Defaults can call functions: each construction gets a fresh id.
var serial = 0;
fn next_id() -> i64 { serial += 1; serial }
struct Rec { id: i64 = next_id(), tag: u8[..4] = "none", score: f64 = 1.0 }

// ---------------------------------------------------------------------
// Field kinds / qualifiers
//   pad          align the NEXT field to its scalar width (foreign layouts)
//   pad 3        exactly 3 unused bytes
//   let f: T     can't be ASSIGNED after construction
//   const f: T   same as `let f: const T`: the contents are read-only too
// Pad bytes are never read, and == ignores them.
// ---------------------------------------------------------------------
struct Hdr {
    magic: u8[4],                             // 4 bytes
    pad,                                      // align `size` (u32) to 4 -> here 0 extra bytes
    size: u32,
    let kind: u8,                             // immutable after construction
    pad 3,                                    // 3 unused bytes
    const name: u8[..8],                      // immutable, and its contents are read-only
}

// ---------------------------------------------------------------------
// Variable-size fields, stored INLINE (no pointers). `varint` is a LEB128
// integer taking only as many bytes as its value needs; reads give an i64.
// A varint field is written ONLY at construction.
// A struct with such a field is variable-class: an array of them is
// sequential (iterate, don't index).
// ---------------------------------------------------------------------
struct Item  { sku: u8[varint], qty: varint, cents: varint }
struct Order { id: varint, customer: u8[varint], items: Item[varint] }

// ---------------------------------------------------------------------
// A resizable tail: only the LAST field may be a resizable array
// (T[>..] or T[>..<]); the struct then becomes resizable too (it can live
// in a local/global/by-value param/result, never as an element).
// ---------------------------------------------------------------------
struct Stack { name: u8[..8], items: i64[>..<] }
// struct Bad { items: i64[>..], n: i64 }     // ERROR: a resizable field must be the LAST one

fn push_twice(s: Stack&, v: i64) { s.items.push(v); s.items.push(v); }   // T& = reference param

// ---------------------------------------------------------------------
// Generic structs: monomorphized like generic functions.
// ---------------------------------------------------------------------
struct Pair<T> { a: T, b: T }

// Optional fields: an optional field with no default is null when left out.
struct Node { v: i64, next: Node? }

// Two structs with the same fields are DIFFERENT types (nominal typing).
struct Vec2 { x: f64, y: f64 }
struct Size2 { x: f64, y: f64 }

fn main() {
    // ---------------------------------------------------------------
    // Literals: named OR positional (the two forms never mix)
    // ---------------------------------------------------------------
    let a = Unit { kind: 1, x: 1.5, name: "scout" };   // named, any order; hp takes its default 100
    let b = Unit { 2, 50, 0.0, "tank" };               // positional, in declaration order
    let c = Unit { kind: 3, .. };                      // `..` fills ALL the rest with defaults
                                                       // (declared default, or zero/false/null/empty)
    let d = default<Unit>();                           // every field at its default
    print("a: ", a);
    print("b: ", b);
    print("c: ", c);
    print("d: ", d);
    print("global selected.hp: ", selected.hp);        // 100: the global started at defaults

    // Positional form: trailing defaulted fields may be left out... but `name`
    // has no default and is last, so all 4 must be given here.
    // let bad = Unit { kind: 1 };            // ERROR: `name` has no default; use `..`

    // ---------------------------------------------------------------
    // Field access with `.` and mutation on a `var`
    // ---------------------------------------------------------------
    var e = Unit { .. };                      // all defaults: kind 0, hp 100, x 0.0, name ""
    e.hp -= 10;                               // compound assignment on a field
    e.kind = 9;
    format(e.name, "medic");                  // a u8[..16] field is a builder up to its capacity
    print("e: ", e, " e.hp=", e.hp, " name cap=", e.name.cap);

    // Defaults are evaluated at each construction (in field order):
    let r1 = Rec { .. };                      // id 1
    let r2 = Rec { score: 2.0 };              // id 2
    let r3 = default<Rec>();                  // id 3
    print("defaults re-evaluated: ", r1, " ", r2, " ", r3.id);

    // ---------------------------------------------------------------
    // Field qualifiers and padding
    // ---------------------------------------------------------------
    var h = Hdr { magic: "GOOS", size: 4, kind: 1, name: "x" };
    h.size = 8;                               // a normal field: assignable
    // h.kind = 2;                            // ERROR: kind is a `let` field
    // h.name.push('y');                      // ERROR: name is `const` (contents read-only)
    // bytes_of(arr) gives the raw element bytes of an ARRAY (it is not available
    // on a bare struct), so wrap the struct in a one-element array literal [h].
    print("hdr: ", h, " name cap=", h.name.cap, " bytes=", bytes_of([h]).len);
    // 4 (magic) + 0 (pad: already aligned) + 4 (size) + 1 (kind) + 3 (pad 3)
    //   + 9 (name: a 1-byte length + 8 bytes of capacity) = 21.
    // Note the pad bytes are not shown in the text form, and == ignores them.

    // ---------------------------------------------------------------
    // Structs are PACKED: no hidden padding.
    // ---------------------------------------------------------------
    let pv = Vec2 { 1.0, 2.0 };
    print("Vec2 is ", bytes_of([pv]).len, " bytes (two f64, no padding)");

    // ---------------------------------------------------------------
    // Variable-size fields inline (varint, u8[varint], Item[varint])
    // ---------------------------------------------------------------
    var book: Order[>..] = [];                // sequential array: iterate only
    book.push(Order { id: 1001, customer: "alice",
                      items: [Item { sku: "SKU-441", qty: 2, cents: 1999 },
                              Item { sku: "SKU-7", qty: 1, cents: 500 }] });
    for o in book {
        var t = 0;
        for it in o.items { t += it.qty * it.cents; }   // varint fields read as i64
        print("order ", o.id, ": ", o.customer, " owes ", t, " cents over ",
              o.items.len, " items, ", bytes_of(book).len, " bytes in all");
    }

    // ---------------------------------------------------------------
    // Resizable tail
    // ---------------------------------------------------------------
    var s = Stack { name: "main", items: [] };
    push_twice(s, 7);                         // a var passes by reference to a Stack& param
    s.items.push(8);
    s.items.pop();                            // the tail grows/shrinks through the struct
    print("stack: ", s.name, " ", s.items, " len=", s.items.len);

    // ---------------------------------------------------------------
    // Generic structs: explicit type argument, or inferred from fields
    // ---------------------------------------------------------------
    let p = Pair<i64> { 1, 2 };               // T = i64, given explicitly
    let q = Pair { a: 0.5, b: 1.5 };          // T inferred as f64
    print("generic: ", p, " ", q);            // the text form includes the type argument

    // ---------------------------------------------------------------
    // Optional field with no default: null when left out
    // ---------------------------------------------------------------
    let n = Node { v: 1, .. };                // `next` left out -> null
    print("node: ", n, " next is null: ", n.next == null);

    // ---------------------------------------------------------------
    // Equality: == compares MEMBERWISE (pads ignored; a reference field
    // compares by identity). Arithmetic operators also apply memberwise.
    // ---------------------------------------------------------------
    let u1 = Vec2 { 1.0, 2.0 };
    let u2 = Vec2 { x: 1.0, y: 2.0 };
    print("u1 == u2: ", u1 == u2, "  u1 != Vec2{0,0}: ", u1 != Vec2 { 0.0, 0.0 });
    print("memberwise +: ", u1 + u2, "  memberwise *: ", u1 * u2);
    // let wrong: Vec2 = Size2 { 1.0, 2.0 };  // ERROR: nominal types -- Size2 is not Vec2
    let sz = Size2 { 3.0, 4.0 };
    print("same fields, different type: ", sz);
    // Ordering operators (< > ...) exist on numbers only, not on structs.

    // ---------------------------------------------------------------
    // Fixed-size structs are plain values: assignment makes an independent copy.
    // ---------------------------------------------------------------
    var m = a;                                // a fixed-size struct copies on assignment
    m.hp = 1;
    print("a.hp=", a.hp, " m.hp=", m.hp);
}
