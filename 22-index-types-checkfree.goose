import std;

// ===================================================================
// 22. Index types and checkfree
// ===================================================================
// An INDEX TYPE `uN in a` is an unsigned integer PROVEN to be < a.len
// for one specific global array `a`. Indexing `a` with it needs no
// bounds check. The check moves to the single place where the index is
// created (`x as (u32 in a)`), instead of every read like `a[b[k]]`.
//
// A BOUND TYPE `uN upto a` is an unsigned integer <= a.len (one past
// the end is allowed), used for the end of a range.
//
// Rules for the array `a`:
//   * a GLOBAL `var` (or `reusable var`) grow-only array `T[>..]`
//   * of fixed-size elements
//   * it can NEVER shrink anywhere (so a valid index stays valid forever)
// The array is part of the type: `u32 in weights` is neither `u32` nor
// `u32 in edges`.

var weights: i32[>..];                    // global grow-only array of fixed-size i32
type WId = u32 in weights;                // an alias: "u32 that is always < weights.len"
var edges: WId[>..];                      // an array OF indices into weights

// `upto`: lo and hi are each <= edges.len, so `lo..hi` is a valid range of edges.
struct Span { lo: u32 upto edges, hi: u32 upto edges }

// ---------------------------------------------------------------
// checkfree: compile error if ANY bounds check remains in the function
// ---------------------------------------------------------------
// Indexing `weights` with a WId needs no check, so this compiles.
// checkfree does not change what the program computes — it's an assertion
// about the generated code. Calls inside must go to other checkfree
// functions, builtins or extern fns.
checkfree fn total(ids: WId[:]) -> i64 {
    var t = 0;
    for id in ids { t += weights[id]; }   // id: WId -> no bounds check on weights[id]
    return t;
}

// Sum the weights the edges in one span point to: edges[k] needs no check
// because k ranges over `upto edges` bounds, and weights[edges[k]] needs
// none because edges holds WIds. So the whole function is checkfree too.
// (`for k in lo..hi` whose bounds are index/bound types of one array gives
// k that array's index type.)
checkfree fn span_total(s: Span) -> i64 {
    var t = 0;
    for k in s.lo..s.hi { t += weights[edges[k]]; }   // k: an index of edges (bounds are upto edges)
    return t;
}

// `assert(b.len >= a.len)` lets the compiler remove checks on b[i] for an
// i that is an index into a. Here `bonus` is a different array than
// `weights`, yet bonus[id] becomes check-free after the assert.
// The assert runs ONCE, outside the loop.
checkfree fn total_with_bonus(ids: WId[:], bonus: i32[>..]&) -> i64 {
    assert(bonus.len >= weights.len);     // the precondition, stated once
    var t = 0;
    for id in ids { t += weights[id] + bonus[id]; }   // both indexings are check-free
    return t;
}

// checkfree fn bad(ids: u32[:]) -> i64 {
//     var t = 0;
//     for id in ids { t += weights[id]; }   // ERROR: "checkfree fn bad keeps a bounds check:
//     return t;                             //         nothing shows id < weights.len"
// }

fn main() {
    // Fill the global arrays.
    weights.push(5);                      // weights = [5]
    weights.push(10);                     // weights = [5, 10]
    weights.push(20);                     // weights = [5, 10, 20]

    // ---------------------------------------------------------------
    // Making an index: `as` is checked at RUN TIME in every build
    // ---------------------------------------------------------------
    edges.push(0 as WId);                 // ok: 0 < weights.len (3)
    edges.push(2 as WId);                 // ok: 2 < 3
    edges.push(1 as WId);
    // edges.push(7 as WId);              // would ABORT at run time: 7 is not < weights.len
    // edges.push(0 as! WId);             // ERROR: `as!` (unchecked cast) cannot make an index type
    // edges.push(0);                     // ERROR: a literal never adapts to an index type
    print("weights = ", weights, ", edges = ", edges);

    // ---------------------------------------------------------------
    // Using an index
    // ---------------------------------------------------------------
    let w = edges[1];                     // w: WId (value 2)
    print("weights[w] = ", weights[w]);   // check-free indexing
    let plain: u32 = w;                   // an index converts IMPLICITLY to a plain integer
    print("plain + 1 = ", plain + 1);     // arithmetic on it gives plain integers
    // var x = w; x += 1;                 // ERROR: compound assignment on an index-typed place

    // A `for` over a count that is weights' length gives indices of weights.
    for i in weights.len { print("  weights[", i, "] = ", weights[i]); }

    // ---------------------------------------------------------------
    // checkfree functions
    // ---------------------------------------------------------------
    print("total(edges) = ", total(edges));               // 5 + 20 + 10

    var bonus: i32[>..] = [1, 2, 3];                      // same length as weights
    print("total_with_bonus = ", total_with_bonus(edges, bonus));   // 35 + (1+3+2)

    // ---------------------------------------------------------------
    // Bound types (`upto`)
    // ---------------------------------------------------------------
    let all = Span { lo: 0 as (u32 upto edges), hi: edges.len as (u32 upto edges) };
    let tail = Span { lo: 1 as (u32 upto edges), hi: edges.len as (u32 upto edges) };
    print("span_total(all) = ", span_total(all), ", span_total(tail) = ", span_total(tail));

    // Never shrink: any shrinking operation on weights or edges is a compile error.
    // weights.pop();                     // ERROR: an array named by an index type can't shrink

    // Tool tip: `goose --bce-lines file.goose` reports which bounds checks
    // remain on each line (useful when a checkfree function is rejected).
    print("done");
}
