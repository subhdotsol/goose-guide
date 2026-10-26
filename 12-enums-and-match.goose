import std;

// =====================================================================
// 12 - Enums and match (syntax.md section 12, docs/reference.md section 9)
//
// An enum is a TAG followed by the payload of one of its variants. It is
// Goose's only form of dynamic polymorphism: no inheritance, no traits,
// no vtables. A variant's payload is declared like struct fields (with the
// same defaults and `..` rules); a variant with no payload is a constant.
// =====================================================================

enum Shape { Circle { r: f64 }, Rect { w: f64, h: f64 }, Dot }

// An enum whose variants all have NO payload is a C-like enum: 1 byte.
enum Color { Red, Green, Blue }

// ---------------------------------------------------------------------
// Named constants for integer match arms (globals).
// A name in a pattern is a VARIANT when the scrutinee is an enum, and a
// CONSTANT when the scrutinee is an integer.
// ---------------------------------------------------------------------
let GROUND = 0;
let SHALLOW = 1;
let DEEP = 4;
let LAVA = 7;

// match is an EXPRESSION: here it is the function's result.
fn terrain(t: i64) -> u8[:] {
    match t {
        GROUND => "ground",                   // a named constant
        SHALLOW..DEEP => "water",             // a HALF-OPEN range: 1, 2, 3 (not 4!)
        LAVA, 10..12, -3 => "hot",            // a comma list of constant, range and literal
        _ => "rock",                          // REQUIRED: an integer match needs `_`
    }
}

// Arms may be any expression, including an `if` expression.
fn name(s: Shape) -> u8[:] {
    match s {
        Circle c => if c.r > 1.0 { "big circle" } else { "circle" },
        Rect r => if r.w == r.h { "square" } else { "rectangle" },
        Dot => "dot",
    }
}

// ---------------------------------------------------------------------
// Case functions: one overload per VARIANT TYPE (Shape.Circle etc.).
// Calling area(s) with a Shape dispatches on the tag through a jump table.
// The compiler checks every variant has exactly one case and that the
// result types agree: adding a variant is a compile error until it has
// its own case. (A "virtual call" without a vtable.)
// ---------------------------------------------------------------------
fn area(s: Shape.Circle) -> f64 { 3.14159 * s.r * s.r }
fn area(s: Shape.Rect) -> f64   { s.w * s.h }
fn area(s: Shape.Dot) -> f64    { 0.0 }

// ---------------------------------------------------------------------
// Recursive enums go through RELATIVE REFERENCES (section 14):
// Expr..&<u16> is a 2-byte offset to an Expr stored in variable mode.
// (An enum may never contain itself by value.)
// ---------------------------------------------------------------------
enum Expr { Num { v: f64 }, Add { l: Expr..&<u16>, r: Expr..&<u16> } }

fn eval(e: Expr.Num&) -> f64 { e.v }                                 // case function by reference
recursive fn eval(e: Expr.Add&) -> f64 { eval(e.l) + eval(e.r) }     // `recursive`: see section 19

fn main() {
    // ---------------------------------------------------------------
    // Variant literals
    // ---------------------------------------------------------------
    // Gotcha: a variant literal on its own has the VARIANT type (Shape.Circle),
    // which cannot be matched on. Annotate `: Shape` to get the whole enum.
    let s: Shape = Shape.Circle { r: 1.0 };   // a variant literal with a payload
    let t: Shape = Shape.Dot;                 // a variant with no payload: no braces
    let rr: Shape = Shape.Rect { w: 2.0, h: 2.0 };
    print("s: ", s, "  t: ", t, "  rr: ", rr);
    let col: Color = Color.Green;
    print("C-like enum: ", col);

    // A variant type (Shape.Circle) is an ordinary type: value, param, field, ref...
    let just_circle: Shape.Circle = Shape.Circle { r: 2.0 };
    print("variant-typed value: ", just_circle, " r=", just_circle.r);

    // ---------------------------------------------------------------
    // Two storage modes, chosen WHERE THE TYPE IS USED:
    //
    // FIXED mode `Shape`: tag + room for the LARGEST payload (every value is
    //   the same size, 17 bytes here). Indexable, and a slot can be
    //   overwritten with a different variant. But you can't point INTO a
    //   payload, so match binds payloads by value only.
    //
    // VARIABLE mode `Shape..`: each value is only as big as its variant.
    //   An array of them is sequential (iterate only), a value can never
    //   change variant, but you MAY take references into a payload.
    // ---------------------------------------------------------------
    var fixedm: Shape[>..] = [];              // fixed mode array
    fixedm.push(Shape.Circle { r: 1.0 });
    fixedm.push(Shape.Dot);
    fixedm[1] = Shape.Rect { w: 1.0, h: 1.0 };   // overwrite with a DIFFERENT variant, in place
    print("fixed mode: ", fixedm, " ", bytes_of(fixedm).len, " bytes (2 x 17)");

    var packed: Shape..[>..] = [];            // variable mode array
    packed.push(Shape.Circle { r: 1.0 });     // 9 bytes: tag + f64
    packed.push(Shape.Rect { w: 2.0, h: 3.0 });   // 17 bytes: tag + 2 f64
    packed.push(Shape.Dot);                   // 1 byte: just the tag
    print("variable mode: ", packed, " ", bytes_of(packed).len, " bytes (9 + 17 + 1)");
    // packed[0];                             // ERROR: a variable-mode array is sequential
                                              //        (iterate it, you can't index it)

    // ---------------------------------------------------------------
    // match on an enum
    //   Circle c  => ...   bind a (read-only) COPY of the payload
    //   Rect &r   => ...   bind BY REFERENCE (variable mode only); can edit
    //   Dot       => ...   no binding
    // Arms are separated by COMMAS; a multi-statement arm uses { ... }.
    // ---------------------------------------------------------------
    for sh in packed {
        match sh {
            Circle c => print("  circle r=", c.r),
            Rect &r => { r.w += 1.0; print("  rect, widened to w=", r.w); },   // edits in place
            Dot => print("  dot"),
        }
    }
    print("after edit through &r: ", packed);

    // In fixed mode only copies are allowed:
    for sh in fixedm {
        match sh {
            Circle c => print("  fixed circle r=", c.r),
            // Rect &r => {},                 // ERROR: a & binder needs a variable-mode scrutinee
            Rect r => print("  fixed rect ", r.w, "x", r.h),
            Dot => print("  fixed dot"),
        }
    }

    // match is an expression; several variants per arm (binds nothing,
    // since their payloads differ), and `_` covers the rest.
    let round = match s { Circle, Dot => true, Rect => false };
    let msg = match s { Circle c => "c", _ => "other" };
    let msg2 = match rr { Circle c => "c", _ => "other" };
    print("round(s)=", round, "  msg(s)=", msg, "  msg(rr)=", msg2);
    print("name(): ", name(Shape.Circle { r: 2.0 }), ", ", name(rr), ", ", name(t));

    // Arms must agree on a type (literals adapt as usual):
    let code = match col { Red => 1, Green => 2, Blue => 3 };
    print("color code: ", code);

    // ---------------------------------------------------------------
    // match on integers: literals, named constants, half-open ranges,
    // comma lists, and a mandatory `_`. The FIRST matching arm wins.
    // ---------------------------------------------------------------
    for v in [0, 2, 4, 7, 11, -3, 20] { print("terrain(", v, ") = ", terrain(v)); }

    let hp = 92;
    let level = match hp {
        0 => "dead",
        1..LAVA => "low",                     // 1 to 6 (LAVA itself is excluded)
        LAVA, 90..95, -3 => "odd",            // 7, 90..94, or -3
        _ => "fine",
    };
    print("hp ", hp, " -> ", level);

    // ---------------------------------------------------------------
    // Rules (things that are compile errors):
    // * A match must be exhaustive: every variant, or `_`.
    //     let x = match s { Circle c => 1, Dot => 2 };     // ERROR: Rect not covered
    // * An integer match needs `_`.
    //     let y = match hp { 0 => 1, 1 => 2 };             // ERROR: missing `_`
    // * An arm already fully covered by earlier arms is an error.
    //     match hp { 0..10 => 1, 5 => 2, _ => 3 }          // ERROR: 5 is unreachable
    // * No variant may be named twice.
    // * NOT in Goose: match guards (`Circle c if c.r > 1`), `|` alternatives
    //   (use `,`), inclusive ranges `..=`, destructuring struct fields in a
    //   pattern (`Rect { w, h }`).
    // ---------------------------------------------------------------

    // ---------------------------------------------------------------
    // Case functions: dispatch on the tag
    // ---------------------------------------------------------------
    var total = 0.0;
    for sh in fixedm { total += area(sh); }   // tag dispatch: each sh picks its overload
    for sh in packed { total += area(sh); }   // works in variable mode too
    print("total area: ", total, "  area(just_circle) = ", area(just_circle));
    // Tag dispatch is used only when no ordinary overload matches the call:
    // area(just_circle) calls the Shape.Circle overload directly.

    // ---------------------------------------------------------------
    // Recursive enum through relative references
    // ---------------------------------------------------------------
    var pool: Expr..[>..] = [];               // variable mode pool of expression nodes
    let a = pool.push(Expr.Num { v: 1.5 });   // push returns a reference to the new node
    let b = pool.push(Expr.Num { v: 2.0 });
    let sum = pool.push(Expr.Add { l: a, r: b });   // links stored as 2-byte offsets
    print("eval(1.5 + 2.0) = ", eval(sum), " in ", bytes_of(pool).len, " bytes");
    // Each Num is 9 bytes (tag + f64), the Add is 5 (tag + two u16 offsets).
}
