import std;

// =====================================================================
// 23. const for — compile-time expansion
// ---------------------------------------------------------------------
// `const for` copies its body ONCE PER ENTRY of a compile-time sequence.
// It is Goose's only form of "reflection": there is NO runtime iterator,
// NO runtime type metadata. Every copy of the body is ordinary code that
// the compiler typechecks like code you wrote by hand.
//
// Sequences you can expand over:
//   fields<T>        -> <N, A>  N = field name (string constant), A = accessor
//   variants<E>      -> <N, V>  N = variant name, V = the variant itself
//   types<T1, T2..>  -> <U>     U = a type
//   [c1, c2, ...]    -> <C>     C = a compile-time constant
//
// Run: build/goose 23-const-for.goose   (from the goose-guide directory,
//      using the path to your goose binary)
// =====================================================================

// A struct to reflect over. `u8[..8]` is an inline string of up to 8 bytes.
struct Point { x: i64, y: i64, label: u8[..8] }

// An enum with payload variants and one bare variant.
enum Shape { Circle { r: i64 }, Rect { w: i64, h: i64 }, Dot }

// ---------------------------------------------------------------------
// fields<T>: one copy of the body per struct field
// ---------------------------------------------------------------------
// Generic over T: `const for` is expanded when the function is
// SPECIALIZED for a concrete T, so it works for any struct type.
fn show_fields<T>(v: T&) {
    // N is the field name as a string constant ("x", "y", "label").
    // A is an *accessor*: `v.A` reads that field, like writing v.x by hand.
    const for <N, A> in fields<T> { print("  ", N, " = ", v.A); }
}

// fields<T> also works INSIDE A STRUCT LITERAL: each copy contributes an
// initializer `A: value,` so the whole constructor is generated.
// F is a block parameter (a function value passed with trailing-block
// syntax) that is called once per field with the name and old value.
fn scaled<T, F>(v: T&) -> T {
    // Expands to: T { x: F("x", v.x), y: F("y", v.y), label: F("label", v.label), }
    T { const for <N, A> in fields<T> { A: F(N, v.A), } }
}

// ---------------------------------------------------------------------
// variants<E>: one copy per enum variant (here as match arms)
// ---------------------------------------------------------------------
fn describe<T>(value: T) {
    match value {
        // Each expansion contributes ONE match arm: `V v => { ... },`.
        // V is written wherever a variant name would go (as a type, a
        // pattern, or a constructor). The generated arms are checked like
        // written ones: every variant must be covered exactly once.
        const for <N, V> in variants<T> {
            V v => {
                print("  variant ", N);
                // Nested const for: fields<V> walks the variant's payload.
                // For `Dot` (no payload) this expands to nothing.
                const for <F, A> in fields<V> { print("    ", F, " = ", v.A); }
            },
        }
    }
}

fn main() {
    // -----------------------------------------------------------------
    // fields<T> — printing every field generically
    // -----------------------------------------------------------------
    var p = Point { x: 2, y: 3, label: "pt" };
    print("show_fields(p):");
    show_fields(p);                       // passes p as a reference (T&)

    // -----------------------------------------------------------------
    // fields<T> in a constructor
    // -----------------------------------------------------------------
    // The trailing block `{ n, x => x }` is F: it receives the field name n
    // and value x and returns the new value (identity here, so q == p).
    let q = scaled(p) { n, x => x };
    print("scaled(p) identity copy: ", q);

    // -----------------------------------------------------------------
    // variants<T> — generated match arms
    // -----------------------------------------------------------------
    print("describe(Rect):");
    // Gotcha: a variant literal like `Shape.Rect { .. }` has the narrower
    // type Shape.Rect; variants<T> needs the whole enum type, so we
    // annotate the binding as `Shape` before passing it to the generic.
    let r: Shape = Shape.Rect { w: 3, h: 4 };
    describe(r);
    print("describe(Circle):");
    let c: Shape = Shape.Circle { r: 9 };
    describe(c);
    print("describe(Dot):");
    let d: Shape = Shape.Dot;             // a payload-less variant is a value
    describe(d);

    // variants<E> can also be used as a plain statement fragment:
    // this simply lists every variant name in declaration order.
    print("all Shape variants:");
    const for <N, V> in variants<Shape> { print("  ", N); }

    // -----------------------------------------------------------------
    // types<...> — one copy per listed type
    // -----------------------------------------------------------------
    // U is bound to i8, then u16, then f32. default<U>() gives that type's
    // zero/default value, so this prints 0, 0, 0.0 (floats print with .0).
    print("default<U>() for types<i8, u16, f32>:");
    const for <U> in types<i8, u16, f32> { print("  ", default<U>()); }

    // -----------------------------------------------------------------
    // [c1, c2, ...] — one copy per compile-time constant
    // -----------------------------------------------------------------
    // C is a CONSTANT in each copy, so it may be used where only constants
    // are allowed — here as a fixed array size `u8[C]`.
    print("fixed arrays u8[C] for C in [1, 2, 4]:");
    const for <C> in [1, 2, 4] { let a: u8[C] = [0; C]; print("  len = ", a.len); }

    // -----------------------------------------------------------------
    // Rules / gotchas
    // -----------------------------------------------------------------
    // * Each statement fragment is its OWN SCOPE per entry: the `let a`
    //   above is three different variables, one per copy, so no clash.
    // * `break` and `continue` cannot cross an expansion — there is no
    //   loop at runtime to break out of. This is a compile error:
    //     for i in 3 { const for <C> in [1, 2] { if C == 2 { break; } } }
    // * Entries of `[...]` must be compile-time constants (literals, named
    //   constants, integer expressions allowed as array sizes). A runtime
    //   variable is rejected:
    //     let n = 3; const for <C> in [n] { }      // error: not a constant
    // * There is no runtime reflection: you cannot iterate the fields of a
    //   value whose type is only known at runtime.
    print("done");
}
