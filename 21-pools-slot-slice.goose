import std;
import slot_pool;
import slice_pool;

// ===================================================================
// 21. Pools: slot_pool and slice_pool
// ===================================================================
// A POOL is a grow-only array with a FREELIST. It is for data whose
// lifetimes don't nest (cache entries, graph nodes that get edited, ...):
// you can free slots in any order and reuse them, without a
// general-purpose allocator.
//
// Pools come from the standard library. Each is a ROOT STRUCT (topic 11)
// whose data lives in an `items` array:
//
//   import slot_pool;   var p = slot_pool<T> {};   — single slots
//   import slice_pool;  var p = slice_pool<T> {};  — contiguous runs
//
// A pool owner is a local or a global, and functions take it as
// `slot_pool<T>&` / `slice_pool<T>&`. It NEVER shrinks.
//
// The builtin `reusable var` / `reusable[] var` pools still compile but are
// DEPRECATED; see the table at the end.

struct Job { n: i32 }

// A global pool works the same way as a local one.
var global_jobs = slot_pool<Job> {};

// Pools are passed by reference, like every root struct.
fn add_job(pool: slot_pool<Job>&, n: i32) -> i64 { pool.alloc_index(Job { n }) }

fn main() {
    // ---------------------------------------------------------------
    // slot_pool: single slots
    // ---------------------------------------------------------------
    var pool = slot_pool<Job> {};               // an empty pool, built by a literal

    let i0 = pool.alloc_index(Job { 1 });       // index of a slot; pushes since the freelist is empty
    let i1 = pool.alloc_index(Job { 5 });       // next slot: index 1
    print("i0 = ", i0, ", i1 = ", i1, ", len = ", pool.items.len);

    pool.free(i0);                              // put slot 0 back on the freelist
    let i2 = pool.alloc_index(Job { 9 });       // REUSES the latest freed slot, 0
    print("after free(i0): i2 = ", i2, " (slot reused), len = ", pool.items.len);

    let jr .= pool.alloc_ref(Job { 2 });        // same, but get a REFERENCE to the slot (bind with .=)
    jr.n += 100;                                // write through the reference
    print("alloc_ref slot value = ", jr.n, ", len = ", pool.items.len);
    let ji = pool.items.index_of(jr);           // reference -> index, through `items`
    print("items.index_of(jr) = ", ji);
    pool.free_ref(jr);                          // free by reference (= pool.free(ji))
    // pool.free(99);  // would ABORT: free checks that the index is in range

    // free never releases memory: `items` is still 3 long.
    print("items.len after free = ", pool.items.len, " (pools never shrink, len counts free slots)");

    // A stale reference/index still reads a VALID value of the right type.
    // Slot `ji` was freed; it still holds its old value until reused...
    print("stale read of freed slot: ", pool.items[ji].n);
    let i3 = pool.alloc_index(Job { 7 });       // ...the next alloc reuses it
    print("after reuse, the same slot holds: ", pool.items[ji].n, " (i3 = ", i3, ")");
    // This is a LOGIC bug (like a stale index), never memory corruption.

    // alloc_with builds the value IN PLACE in the chosen slot. The block
    // runs once, after the slot is picked; it is needed for values with
    // `self` links (topic 14).
    let built .= pool.alloc_with() { Job { 33 } };
    print("alloc_with built ", built.n, " at index ", pool.items.index_of(built));

    // Iterate or index the data through `items` (free slots included).
    var sum = 0;
    for j in pool.items { sum += j.n; }
    print("sum over items = ", sum);

    // Pool reference parameter + a global pool.
    let g0 = add_job(global_jobs, 11);
    let g1 = add_job(global_jobs, 12);
    global_jobs.free(g0);
    let g2 = add_job(global_jobs, 13);          // reuses g0's slot through the parameter
    print("global pool: g0 = ", g0, ", g1 = ", g1, ", g2 = ", g2, ", len = ", global_jobs.items.len);

    // recycle_all makes every slot reusable at once, without shrinking.
    global_jobs.recycle_all();
    print("after recycle_all, the next index is ", add_job(global_jobs, 14));

    // ---------------------------------------------------------------
    // slice_pool: runs of elements
    // ---------------------------------------------------------------
    // Hands out contiguous RUNS. Its freelist holds spans and merges neighbours.
    var spans = slice_pool<i64> {};

    var s1 = spans.alloc_slice(3);              // 3 default-valued (0) elements
    s1[0] = 1; s1[1] = 2; s1[2] = 3;            // a plain slice: index and write it
    print("s1 = ", s1, ", items = ", spans.items);

    s1 = spans.realloc_slice(s1, 5);            // resize to 5: s1 ends the array, so it grows IN PLACE
    print("s1 = ", s1, " (grown in place, new elements are 0)");

    let s3 = spans.alloc_copy([7, 8]);          // allocate a run and copy into it in one step
    spans.free_slice(s1);                       // give s1's 5 elements back
    let s4 = spans.alloc_slice(2);              // taken from the freed span, RESET to defaults
    print("s4 = ", s4, " (reused from freed span), s3 = ", s3);
    print("items.len = ", spans.items.len, ", items = ", spans.items);
    spans.free_slice(s4);                       // free the run we just got
    spans.free_slice(s3);

    // Rules:
    //   spans.alloc_index(1);   // ERROR: slice_pool has no single-slot functions
    //   pool.alloc_slice(2);    // ERROR: slot_pool has no slice functions
    //   let c = copy(pool);     // ERROR: root owners cannot be copied; bind a reference instead
    //   (a plain `let c = pool;` is fine: it binds a reference to the owner)
    // free_slice/realloc_slice must get one of the pool's own runs; a run
    // from somewhere else aborts at run time ("slice is not from this pool").
    // Don't shrink or replace `items` or edit the bookkeeping fields yourself.

    // ---------------------------------------------------------------
    // Moving off the deprecated builtin pools
    // ---------------------------------------------------------------
    //   reusable var p: T[>..] = [];    ->  var p = slot_pool<T> {};
    //   reusable[] var p: T[>..] = [];  ->  var p = slice_pool<T> {};
    //   p[i], p.len, for x in p         ->  p.items[i], p.items.len, for x in p.items
    //   u32 in p, Node&<u32 in p>       ->  u32 in p.items, Node&<u32 in p.items>
    //   p.free(p.index_of(r))           ->  p.free_ref(r)
    print("done");
}
