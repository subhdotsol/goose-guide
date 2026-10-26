import std;

// =====================================================================
// 13. References and optionals
//
// `T&` is a reference to a T: one machine address. Rules from the cheat sheet:
//   - references are never null, never dangle, and allow no pointer arithmetic;
//   - references are TRANSPARENT: no `*`, no `->`; using r means using its target;
//   - `.=` binds/rebinds a reference, `=` copies or writes through;
//   - `.==` / `.!=` compare addresses, `==` / `!=` compare values.
//
// `T?` is an OPTIONAL: a nullable reference (null is address 0, no extra space).
// An optional is NOT transparent: it must be NARROWED (if / while / guard /
// assert / comparison with null) before you can use it.
// =====================================================================

// ---------------------------------------------------------------
// A reference parameter: `n: i64&`.
// The caller passes a plain lvalue (no `&`) and the function writes through it.
// ---------------------------------------------------------------
fn inc(n: i64&) { n += 1; }               // `n += 1` writes the caller's variable

// ---------------------------------------------------------------
// A struct with a reference field: it binds an lvalue without `&`, too.
// ---------------------------------------------------------------
struct Cursor { line: i64& }               // line refers to some i64 living elsewhere

// ---------------------------------------------------------------
// A function returning an optional: `-> i64?`.
// `return x;` returns a reference to the element; `return null;` means "none".
// ---------------------------------------------------------------
fn first_at_least(xs: i64[:], min: i64) -> i64? {
    for &x in xs { if x >= min { return x; } }   // `&x` walks by reference, so x is an lvalue
    return null;                                 // the empty optional
}

// ---------------------------------------------------------------
// A linked list node whose `next` is optional: an omitted optional field is null.
// ---------------------------------------------------------------
struct Node { v: i64, next: Node? }

// guard narrowing: after `guard o else { ... }` the optional is usable.
fn value_or_zero(o: i64?) -> i64 {
    guard o else { return 0; }    // if o is null, leave the function
    o                             // narrowed: o behaves like an i64& here
}

// assert narrowing: `assert(o)` narrows for the rest of the block (aborts if null).
fn must_have(o: i64?) -> i64 {
    assert(o);                    // traps at runtime if o is null
    o * 10                        // narrowed: o is transparent now
}

fn main() {
    // ---------------------------------------------------------------
    // Binding a reference with `.=`
    // ---------------------------------------------------------------
    var xs: i64[>..] = [10, 20, 30];   // a growable array (non-fixed, lives on a data stack)
    var r .= xs[0];                    // `.=` binds r as a REFERENCE to xs[0]
    var c = xs[0];                     // `=` on a fixed-size value makes a COPY
    r = 11;                            // writes xs[0]: references are transparent (no * or ->)
    c = 99;                            // writes only the copy; xs is untouched
    print("after r = 11: xs = ", xs, ", copy c = ", c);

    r .= xs[2];                        // rebind r: it now refers to xs[2]
    r += 1;                            // compound assignment writes through too: xs[2] = 31
    print("after rebind + r += 1: xs = ", xs, ", r = ", r);

    // ---------------------------------------------------------------
    // Address comparison vs value comparison
    // ---------------------------------------------------------------
    print("r .== xs[2] (same address): ", r .== xs[2]);   // true: r points at xs[2]
    print("r .!= xs[0] (other address): ", r .!= xs[0]);  // true: different elements
    print("r == xs[2] (same value): ", r == xs[2]);       // value comparison of targets
    xs[1] = 31;                                           // make xs[1] hold the same value
    print("r == xs[1]: ", r == xs[1], ", r .== xs[1]: ", r .== xs[1]);  // equal value, different address

    // ---------------------------------------------------------------
    // `&` makes a reference explicitly
    // ---------------------------------------------------------------
    let p = &xs[1];                    // inferred type is i64&, because of the explicit &
    p = 21;                            // a `let` reference can't be REBOUND, but can be WRITTEN THROUGH
    print("after p = 21 via let p = &xs[1]: xs = ", xs);
    // p .= xs[0];                     // ERROR: a `let` reference cannot be rebound (use `var p .= ...`)
    // let t = &(1 + 2);               // ERROR: you cannot take a reference into a temporary;
    //                                 //        bind the temporary to a variable first:
    let three = 1 + 2;                 // ...like this
    let t = &three;                    // now it's an lvalue, so & is fine
    print("reference to a named value: ", t);

    // ---------------------------------------------------------------
    // Reference parameters and fields bind an lvalue WITHOUT `&`
    // ---------------------------------------------------------------
    var count = 0;
    inc(count);                        // binds count by reference: count is now 1
    inc(count);                        // count is now 2
    // inc(&count);                    // works but WARNS: the & is redundant where the type is a reference
    // inc(5);                         // ERROR: a literal is a temporary, not an lvalue
    print("count after two inc(): ", count);

    let rr: i64& = count;              // an ANNOTATED reference variable: binds count, no & needed
    rr += 10;                          // writes count
    print("count after rr += 10: ", count);

    let cur = Cursor { line: count };  // reference field binds count (again without &)
    cur.line += 100;                   // writes count through the struct's field
    print("count after cur.line += 100: ", count);

    // ---------------------------------------------------------------
    // Decay rules for inferred bindings
    //  - fixed-size value: `let x = r;` makes a COPY (the reference decays)
    //  - `let x .= r;` keeps the reference
    //  - a non-fixed value (like i64[>..]) ALWAYS binds by reference
    // ---------------------------------------------------------------
    var n = 1;
    var ref_n .= n;                    // a reference to n
    let copy_n = ref_n;                // i64 is fixed-size: this decays to a COPY
    let keep_n .= ref_n;               // `.=` keeps the reference (points at n)
    keep_n += 5;                       // writes n
    print("n = ", n, ", copy_n (decayed copy) = ", copy_n, ", ref_n = ", ref_n);

    let alias = xs;                    // xs is non-fixed: this is a REFERENCE, not a copy
    alias.push(40);                    // so pushing through alias grows xs itself
    print("xs after alias.push(40): ", xs);

    // ---------------------------------------------------------------
    // Optionals `T?`: narrowed by `if`
    // ---------------------------------------------------------------
    let data = [1, 7, 3];              // a fixed array literal; passes as a slice i64[:]
    let o = first_at_least(data, 5);   // o: i64?  -> refers to data[1]
    if o { print("got ", o); } else { print("none"); }   // inside `if o`, o is narrowed to i64&
    // print(o + 1);                   // ERROR outside a narrowed region: an optional is not transparent
    print("o == null: ", o == null);   // comparing with null is always allowed

    let missing = first_at_least(data, 100);
    if missing { print("got ", missing); } else { print("none (missing is null)"); }
    print("missing == null: ", missing == null);

    // Comparison with null also narrows:
    if o != null { print("o != null narrows too: ", o); }

    // ---------------------------------------------------------------
    // Optionals narrowed by `while`: walking a linked list
    // The condition is re-tested each iteration, so rebinding `cur` inside
    // the body keeps working.
    // ---------------------------------------------------------------
    var c3 = Node { v: 3, next: null };   // explicit null
    var c2 = Node { v: 2, next: c3 };     // optional field binds c3 by reference (no &)
    var c1 = Node { v: 1, next: c2 };
    var walk: Node? = c1;                 // an optional variable, starts non-null
    var sum = 0;
    while walk {                          // narrowed for the body
        sum += walk.v;                    // transparent access to the node
        walk .= walk.next;                // rebind the optional (may become null)
    }
    print("list sum via while-narrowing: ", sum);

    // ---------------------------------------------------------------
    // Optionals narrowed by `guard` and `assert` (see the helper functions above)
    // ---------------------------------------------------------------
    print("guard: value_or_zero(o) = ", value_or_zero(o), ", value_or_zero(missing) = ", value_or_zero(missing));
    print("assert: must_have(o) = ", must_have(o));
    // must_have(missing);             // would ABORT at runtime: assert fails on null

    // ---------------------------------------------------------------
    // A narrowed optional writes through like any reference
    // ---------------------------------------------------------------
    var nums: i64[>..] = [2, 9, 4];
    let hit = first_at_least(nums, 5); // refers to nums[1]
    if hit { hit = 900; }              // writes nums[1] through the narrowed optional
    print("nums after writing through narrowed optional: ", nums);
}
