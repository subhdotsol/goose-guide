import std;

// =====================================================================
// 10 - Slices (syntax.md section 10, docs/reference.md section 7)
//
// A slice T[:] is a REFERENCE PLUS A LENGTH: a view of a contiguous run
// of Ts inside some array. It NEVER copies elements. It is the universal
// "process a range" parameter type, because every array kind coerces to
// a slice of itself for free.
// =====================================================================

// Every array kind (fixed, frozen, limited, grow-only, ...) can be passed
// here: it becomes a slice of the whole array, as if written a[..].
fn total(xs: i64[:]) -> i64 { var t = 0; for x in xs { t += x; } return t; }

// `const T[:]` documents (and enforces) that the function only READS.
fn first_or_zero(xs: const i64[:]) -> i64 {
    if xs.len == 0 { return 0; }              // .len works on slices too (an i64)
    return xs[0];                             // indexing is bounds-checked against the SLICE's length
}

// A plain T[:] parameter can write through the slice when given a writable one.
fn double_all(xs: i64[:]) { for &x in xs { x *= 2; } }   // `for &x` binds each element by reference

fn main() {
    let grow_init: i64[>..] = [10, 20, 30, 40, 50];
    var grow = copy(grow_init);               // a writable grow-only array to slice

    // ---------------------------------------------------------------
    // Slicing syntax: a[x..y] -- the END IS EXCLUSIVE
    // ---------------------------------------------------------------
    let a = grow[1..4];                       // [20, 30, 40]: indices 1, 2, 3
    let b = grow[..2];                        // first two: indices 0, 1
    let c = grow[2..];                        // from index 2 to the end
    let d = grow[^2..];                       // last two: ^k means len - k
    let e = grow[..];                         // the whole array
    print("a=grow[1..4]: ", a);
    print("b=grow[..2]:  ", b);
    print("c=grow[2..]:  ", c);
    print("d=grow[^2..]: ", d);
    print("e=grow[..]:   ", e);
    print("grow[1..^1]:  ", grow[1..^1]);     // ^ works on either bound: drop first and last

    // Re-slicing a slice is always allowed and never grows it.
    let inner = a[1..];                       // [30, 40]: a slice of a slice
    print("a[1..]: ", inner, " len=", inner.len);

    // ---------------------------------------------------------------
    // Coercion: every array kind becomes a slice where a slice is expected
    // (parameter, annotated variable, assignment, field, push, return...).
    // ---------------------------------------------------------------
    let fixed: i64[4] = [1, 2, 3, 4];
    let frozen: i64[] = [100, 200];
    var limited: i64[..4] = [];
    limited.push(7);
    print("total(grow)=", total(grow), " total(fixed)=", total(fixed),
          " total(frozen)=", total(frozen), " total(limited)=", total(limited));
    print("total(grow[1..3])=", total(grow[1..3]));   // a sub-slice works just the same
    let view: const i64[:] = fixed;           // annotated variable: a view of `fixed` itself
    print("view of fixed: ", view, " first_or_zero: ", first_or_zero(view));

    // ---------------------------------------------------------------
    // A slice never copies: it is a window onto the original elements.
    // Writability: a slice of a `var` array is writable through.
    // ---------------------------------------------------------------
    double_all(grow[..2]);                    // writes THROUGH the slice into grow
    print("after double_all(grow[..2]): ", grow);
    var w = grow[2..];                        // a writable slice of a var array
    w[0] = -1;                                // writes grow[2]
    print("after w[0] = -1: ", grow);

    // A literal or a slice of a `const` value is NOT writable:
    // double_all(grow_init);                 // ERROR: grow_init is a `let` (const) array
    // double_all([1, 2, 3]);                 // ERROR: a literal is read-only
    // But reading through const slices is fine:
    print("total of a let array: ", total(grow_init), " of a literal: ", total([1, 2, 3]));

    // ---------------------------------------------------------------
    // Slices compare structurally with ==.
    // ---------------------------------------------------------------
    let s = grow[3..];
    print("s=", s, " s == [40, 50]: ", s == [40, 50]);

    // ---------------------------------------------------------------
    // A slice of a grow-only array taken BEFORE a push stays valid,
    // but does not include the new elements.
    // ---------------------------------------------------------------
    let before = grow[..];
    grow.push(60);
    print("slice taken before push: ", before, " (len ", before.len, "), grow now: ", grow);

    // ---------------------------------------------------------------
    // Lifetime rules (checked by the compiler, by LIVENESS not scope):
    // * A slice cannot outlive its root (the variable it views).
    // * The array cannot shrink while a slice into it is still used.
    // ---------------------------------------------------------------
    var line: u8[>..] = [];
    line.append("hello world");
    let word = line[..5];                     // a view of "hello"
    print("word: ", word);
    line.clear();                             // OK: `word` is never used after this line
    line.append("again");
    let all = line[..];
    // line.clear();                          // ERROR: cannot clear line while `all` is still used
    print("all: ", all);

    // ---------------------------------------------------------------
    // Strings are u8 slices too: string helpers return views into the input.
    // ---------------------------------------------------------------
    let text = "key=value";
    let k = text[..3];                        // a const u8[:] view, no bytes copied
    let v = text[4..];
    print("key='", k, "' value='", v, "'");
}
