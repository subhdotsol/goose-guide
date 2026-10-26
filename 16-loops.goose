import std;

// =====================================================================
// 16. Loops
//
// Goose has `for ... in`, `while`, and `loop` (infinite).
//   - `break`, `break value;` and `continue` work; there are NO LABELS.
//   - There is no `step` and no reverse range: use `while`, a helper
//     function, or `each_rev(xs) { ... }` / `reverse(xs)` from std.
//   - Pushing to a growable array during a by-value `for` over it EXTENDS the walk.
// =====================================================================

// Helper used to print a loop's visited values on one line.
fn show(label: const u8[:], xs: i64[:]) { print(label, xs); }

fn main() {
    var seen: i64[>..] = [];             // reused to collect each loop's values

    // ---------------------------------------------------------------
    // for i in N: counts 0, 1, ..., N-1
    // ---------------------------------------------------------------
    seen.clear();
    for i in 3 { seen.push(i); }
    show("for i in 3:          ", seen);   // [0, 1, 2]

    // ---------------------------------------------------------------
    // for i in a..b: a HALF-OPEN range (b is excluded)
    // ---------------------------------------------------------------
    seen.clear();
    for i in 10..13 { seen.push(i); }
    show("for i in 10..13:     ", seen);   // [10, 11, 12]

    // ---------------------------------------------------------------
    // Typed loop variable: `for i: T in ...`
    // ---------------------------------------------------------------
    var total32: i32 = 0;
    for i: i32 in 0..10 { total32 += i; }  // i is an i32, so no cast is needed to add to an i32
    print("for i: i32 in 0..10, sum = ", total32);

    // Every u8: the range 0..256 is exactly the u8 values 0..255 (256 itself is excluded).
    var count_u8 = 0;
    var last_u8: u8 = 0;
    for i: u8 in 0..256 { count_u8 += 1; last_u8 = i; }
    print("for i: u8 in 0..256 visits ", count_u8, " values, last = ", last_u8);

    // ---------------------------------------------------------------
    // Iterating an array
    // ---------------------------------------------------------------
    var xs: i64[>..] = [1, 2, 3];

    // By VALUE: x is a copy of each (fixed-size) element.
    var s = 0;
    for x in xs { s += x; }
    print("for x in xs (by value), sum = ", s);

    // By REFERENCE: `&x` binds each element, so writes mutate the array in place.
    for &x in xs { x *= 2; }
    print("for &x in xs { x *= 2; } -> ", xs);   // [2, 4, 6]

    // Element plus index (the index is an i64 by default).
    for x, i in xs { print("  xs[", i, "] = ", x); }

    // A narrower index type: grid has 16 elements, so its length fits a u8.
    var grid: u8[16] = [0; 16];          // a fixed array of 16 zeros (fill form)
    for x, i: u8 in grid { grid[i] = i * 2 + x; }   // i is a u8: usable directly in u8 arithmetic
    seen.clear();
    for g in grid { seen.push(g); }         // u8 arrays print as TEXT, so copy into the i64 array (u8 widens implicitly)
    show("for x, i: u8 in grid -> ", seen);

    // Over a literal.
    seen.clear();
    for v in [3, 0, 4] { seen.push(v); }
    show("for v in [3, 0, 4]:  ", seen);

    // ---------------------------------------------------------------
    // while cond { }
    // ---------------------------------------------------------------
    var n = 1;
    while n < 100 { n *= 3; }            // 1, 3, 9, 27, 81, 243
    print("while n < 100 { n *= 3 } -> n = ", n);

    // ---------------------------------------------------------------
    // loop { }: infinite until `break`
    // ---------------------------------------------------------------
    var ticks = 0;
    loop {
        ticks += 1;
        if ticks == 4 { break; }         // plain break leaves the loop
    }
    print("loop with break after ", ticks, " ticks");

    // A loop WITH A VALUE: `break value;` makes the loop an expression.
    var m = 1;
    let found = loop { m += 7; if m % 5 == 0 { break m; } };   // 8, 15 -> 15
    print("let found = loop { ... break m; } -> ", found);

    // ---------------------------------------------------------------
    // continue: skip to the next iteration
    // ---------------------------------------------------------------
    seen.clear();
    for i in 10 {
        if i % 3 != 0 { continue; }      // keep only multiples of 3
        seen.push(i);
    }
    show("continue keeps multiples of 3: ", seen);

    // ---------------------------------------------------------------
    // No labels: `break` only leaves the INNERMOST loop.
    // To leave nested loops, use a flag (or a function and `return`).
    // ---------------------------------------------------------------
    var done = false;
    var hit_i = -1;
    var hit_j = -1;
    for i in 5 {
        for j in 5 {
            if i * j == 6 { hit_i = i; hit_j = j; done = true; break; }  // leaves only the j loop
        }
        if done { break; }               // the flag carries the exit out of the i loop
    }
    print("nested search i*j == 6: i = ", hit_i, ", j = ", hit_j);
    // break outer;                      // ERROR: no labels; `outer` is read as a break VALUE ("break with a value exits loop/block only")

    // ---------------------------------------------------------------
    // No step / no reverse range. Alternatives:
    // ---------------------------------------------------------------
    // for i in 10..0 { }                // does NOT count down: an empty range, the body never runs
    seen.clear();
    var k = 10;
    while k > 0 { seen.push(k); k -= 3; }    // a "step" of -3 with while
    show("while with step -3:  ", seen);

    seen.clear();
    for i in 4 { seen.push(i * 5); }     // a "step" of 5 by scaling the counter
    show("step 5 by scaling:   ", seen);

    seen.clear();
    let ys = [1, 2, 3, 4];
    each_rev(ys) { seen.push(it); };     // std: calls the trailing block last-to-first; `it` is the element
    show("each_rev(ys):        ", seen);

    var zs: i64[>..] = [1, 2, 3, 4];
    reverse(zs);                         // std: reverses in place
    show("reverse(zs):         ", zs);

    // ---------------------------------------------------------------
    // Pushing during a by-value `for` over a growable array EXTENDS the walk:
    // the loop re-reads the length each step, so new elements are visited too.
    // ---------------------------------------------------------------
    var grow: i64[>..] = [1, 2];
    var visited: i64[>..] = [];
    for g in grow {
        visited.push(g);
        if g < 4 { grow.push(g + 2); }   // 1 -> push 3, 2 -> push 4, 3 -> push 5
    }
    show("walk extended by push: ", visited);   // [1, 2, 3, 4, 5]
}
